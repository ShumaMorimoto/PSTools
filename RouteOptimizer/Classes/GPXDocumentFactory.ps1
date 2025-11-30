class GPXDocumentFactory {
    #region Static Properties
    hidden static [string] $NominatimSearchUrl = "https://nominatim.openstreetmap.org/search"
    hidden static [string] $NominatimReverseUrl = "https://nominatim.openstreetmap.org/reverse"
    hidden static [string] $OverpassUrl = "https://overpass-api.de/api/interpreter"
    hidden static [hashtable] $ApiHeaders = @{ "User-Agent" = "PowerShell-GPXFactory-Client/1.0" }
    #endregion 

    #region Public Factory Methods
    static [GPXDocument] FromCityTowns([string]$Keyword) {
        return [GPXDocumentFactory]::FromCityTowns($Keyword, $false)
    }
    static [GPXDocument] FromCityTowns([string]$Keyword, [bool]$ResolveAddress = $false) {
        $center = [GPXDocumentFactory]::_ResolveCenterPoint($Keyword, $true)
        if (-not $center) { return $null }
        $gpx = [GPXDocument]::new($center)
        $areaId = [GPXDocumentFactory]::_GetOverpassAreaId($center.lat, $center.lon)
        if (-not $areaId) {
            Write-Warning "行政界が未取得"
            return $gpx
        }
        $query = @"
[out:json];
area($areaId)->.a;
node(area.a)["place"~"^(neighbourhood|quarter)$"];
out body;
"@
        $towns = [GPXDocumentFactory]::_InvokeOverpassQuery($query)

        [GPXDocumentFactory]::_AddTownsToDoc($gpx, $towns, $ResolveAddress)
        return $gpx
    }
    static [GPXDocument] FromAreaTowns([string]$Keyword) {
        return [GPXDocumentFactory]::FromAreaTowns($Keyword, 2, $false)
    }
    static [GPXDocument] FromAreaTowns([string]$Keyword, $RadiusKm) {
        return [GPXDocumentFactory]::FromAreaTowns($Keyword, $RadiusKm, $false)
    }
    static [GPXDocument] FromAreaTowns([string]$Keyword, [double]$RadiusKm, [bool]$ResolveAddress = $false) {
        $center = [GPXDocumentFactory]::_ResolveCenterPoint($Keyword, $false)
        if (-not $center) { return $null }
        $gpx = [GPXDocument]::new($center)
        $r = [math]::Round($RadiusKm * 1000)
        $query = @"
[out:json];
node(around:$r,$($center.lat),$($center.lon))["place"~"^(neighbourhood|quarter)$"];
out body;
"@
        $towns = [GPXDocumentFactory]::_InvokeOverpassQuery($query)
        [GPXDocumentFactory]::_AddTownsToDoc($gpx, $towns, $ResolveAddress)
        return $gpx
    }

    static [GPXDocument] Search([string]$Keyword) {
        $results = [GPXDocumentFactory]::_InvokeNominatimSearch($Keyword, 100)
        if (-not $results) {
            Write-Warning "結果が得られませんでした"
            return $null
        }
        $gpx = [GPXDocument]::new(@{
                name = "Keyword Search: $Keyword"
                desc = "Nominatim search results for keyword '$Keyword' in Japan"
            })
        $now = (Get-Date).ToString("o")
        foreach ($res in $results) {
            $addr = $res.address
            $enriched = $addr.PSObject.Copy()
            $enriched | Add-Member -NotePropertyName "keyword" -NotePropertyValue $Keyword -Force
            $enriched | Add-Member -NotePropertyName "timstamp" -NotePropertyValue $now -Force
            $gpx.AppendTrkPt(@{
                    lat     = [double]$res.lat
                    lon     = [double]$res.lon
                    name    = $res.name
                    desc    = $res.display_name
                    address = $enriched
                })
        }
        return $gpx
    }
    static [GPXDocument] EnrichTrkPts(
        [GPXDocument]$gpx,
        [switch]$ForceUpdate
    ) {
        if (-not $gpx) { throw "GPXDocumentが指定されていません。" }

        $trkpts = $gpx.GetTrkPts()
        if (-not $trkpts -or $trkpts.Count -eq 0) { return $null }

        $total = $trkpts.Count
        $updated = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        # (A) 住所情報がないものだけフィルタリング
        $targets = @()
        foreach ($pt in $trkpts) {
            $extNode = $pt.SelectSingleNode("gpx:extensions", [GPXDocument]::NamespaceManager)
            $hasAddressInfo = $false
            if ($extNode) {
                $addrNode = $extNode.SelectSingleNode("gpx:province", [GPXDocument]::NamespaceManager)
                if ($addrNode -and -not [string]::IsNullOrWhiteSpace($addrNode.InnerText)) {
                    $hasAddressInfo = $true
                }
            }

            if ($ForceUpdate -or -not $hasAddressInfo) {
                $targets += $pt
            }
        }

        if ($targets.Count -eq 0) {
            $sw.Stop()
            Write-Host "ℹ️ EnrichTrkPts: 住所解決対象なし (総数=$total, 更新=0, 時間=$($sw.ElapsedMilliseconds)ms)"
            return $gpx
        }

        # (B) ResolveLocations は対象のみ
        $resolved = [GPXDocumentFactory]::ResolveLocations($targets)

        foreach ($r in $resolved) {
            $pt = $r.item
            $res = $r.result
            if (-not $res -or -not $res.address) { continue }

            # (1) extensions
            $extNodeOld = $pt.SelectSingleNode("gpx:extensions", [GPXDocument]::NamespaceManager)
            if ($extNodeOld) { $pt.RemoveChild($extNodeOld) | Out-Null }
            $extNode = $gpx.CreateElementFromPSO("extensions", $res.address)
            $pt.AppendChild($extNode) | Out-Null
            $updated++

            # (2) name 補完
            $nameNode = $pt.SelectSingleNode("gpx:name", [GPXDocument]::NamespaceManager)
            if (-not $nameNode) {
                $nameNode = $gpx.CreateElement("name", [GPXDocument]::GpxNamespace)
                $pt.AppendChild($nameNode) | Out-Null
            }
            if ([string]::IsNullOrWhiteSpace($nameNode.InnerText) -and $res.name) {
                $nameNode.InnerText = $res.name
            }

            # (3) desc 補完
            $descNode = $pt.SelectSingleNode("gpx:desc", [GPXDocument]::NamespaceManager)
            if (-not $descNode) {
                $descNode = $gpx.CreateElement("desc", [GPXDocument]::GpxNamespace)
                $pt.AppendChild($descNode) | Out-Null
            }
            if ([string]::IsNullOrWhiteSpace($descNode.InnerText) -and $res.display_name) {
                $descNode.InnerText = $res.display_name
            }
        }

        $gpx.UpdateStats()
        $sw.Stop()

        Write-Host ("✅ EnrichTrkPts 完了: 総数={0}, 更新={1}, 時間={2}ms" -f $total, $updated, $sw.ElapsedMilliseconds) -ForegroundColor Green
        return $gpx
    }    #endregion

    #region --- 町字ノード追加ロジック ---
    static [object[]] ResolveLocations([object[]]$items) {
        # 静的プロパティの値をローカル変数にコピー
        $urlTemplate = "$([GPXDocumentFactory]::NominatimReverseUrl)?lat={0}&lon={1}&format=json&addressdetails=1"
        $headers = [GPXDocumentFactory]::ApiHeaders

        if ($items.Count -gt 1) {
            # --- 並列実行 ---
            Write-Verbose "実行モード: 並列 ($($items.Count)件)"
            
            $results = $items | ForEach-Object -Parallel {
                # $processScriptBlockの内容をここに展開
                $lat = [double]$_.'lat'; $lon = [double]$_.'lon'               
                $uri = $using:urlTemplate -f $lat, $lon

                try {
                    $res = Invoke-RestMethod -Uri $uri -Headers $using:headers
                    [PSCustomObject]@{ item = $_; result = $res }
                } 
                catch {
                    # Write-Warning は並列処理ではコンソールに順序通り表示されないことがある
                    # エラー情報を返す方がより堅牢
                    [PSCustomObject]@{ item = $_; result = $null; error = "逆引き失敗: $($_.Exception.Message)" }
                }
            } -ThrottleLimit 20
        }
        else {
            # --- 直列実行 ---
            Write-Verbose "実行モード: 直列 (1件)"

            # 直列の場合は共通スクリプトブロック化が可能なので、再利用性のために定義する
            $processScriptBlock = {
                param($item) # 引数を$itemのみに限定
                $lat = [double]$item.lat; $lon = [double]$item.lon
                $uri = $urlTemplate -f $lat, $lon # $using不要
                try {
                    $res = Invoke-RestMethod -Uri $uri -Headers $headers # $using不要
                    [PSCustomObject]@{ item = $item; result = $res }
                }
                catch {
                    Write-Warning "逆引き失敗 (Lat: $lat, Lon: $lon): $($_.Exception.Message)"
                    [PSCustomObject]@{ item = $item; result = $null }
                }
            }
            # $itemsは1件しかないのでパイプラインでも直接呼び出しでも良い
            $results = @(& $processScriptBlock -item $items[0])
        }
 
        return @($results)
    }

    #endregion --- 町字ノード追加ロジック ---

    #region Public Helpers

    static [object[]] ResolveKeyword([string]$Keyword, [bool]$MunicipalityOnly) {
        try {
            $result = [GPXDocumentFactory]::_InvokeNominatimSearch($Keyword, 20)
            if ($MunicipalityOnly) {
                return @($result | Where-Object { $_.addresstype -in @("city", "town", "village", "suburb", "municipality") })
            }
            return @($result)
        }
        catch {
            Write-Error "Nominatim失敗: $($_.Exception.Message)"
            return @()
        }
    }
    static [hashtable] ResolveLocation([double]$lat, [double]$lon) {
        $resolved = [GPXDocumentFactory]::ResolveLocations( @{ lat = $lat; lon = $lon })
        if (-not $resolved -or $resolved.Count -eq 0) { return $null }

        $r = $resolved.result
        if (-not $r) { return $null }

        return @{
            lat     = $lat
            lon     = $lon
            name    = $r.name
            desc    = $r.display_name
            address = $r.address
        }
    }

    #region Hidden/Private Helper Methods

    hidden static [object] InvokeWithRetry(
        [scriptblock]$act,
        [int]$MaxRetry = 5,
        [int]$DelaySec = 3
    ) {
        [Exception]$last = $null
        for ($i = 1; $i -le $MaxRetry; $i++) {
            try {
                return & $act   # 成功したら必ず return
            }
            catch {
                $last = $_.Exception
                if ($i -lt $MaxRetry) {
                    Start-Sleep -Seconds $DelaySec
                }
            }
        }
        # ここまで来たら全て失敗
        throw $last ?? [System.Exception]::new("InvokeWithRetry failed after $MaxRetry attempts.")
    }
    
    hidden static [hashtable] _ResolveCenterPoint([string]$Keyword, [bool]$MunicipalityOnly) {
        if ($Keyword -match '^\s*(-?\d+(\.\d+)?)\s*,\s*(-?\d+(\.\d+)?)\s*$') {
            $lat = [double]$matches[1]; $lon = [double]$matches[3]
            return [GPXDocumentFactory]::ResolveLocation($lat, $lon)
        }
        $candidates = [GPXDocumentFactory]::ResolveKeyword($Keyword, $MunicipalityOnly)
        if (-not $candidates) { return $null }
        $sel = [GPXDocumentFactory]::_SelectPlaceFromCandidates($candidates)
        if (-not $sel) { return $null }
        return @{ lat = [double]$sel.lat; lon = [double]$sel.lon; name = $sel.name; desc = $sel.display_name; address = $sel.address }
    }
    hidden static [object] _SelectPlaceFromCandidates([object[]]$candidates) {
        if ($candidates.Count -eq 0) { return $null }
        if ($candidates.Count -eq 1) { return $candidates[0] }
        Write-Host "複数候補: 選択して下さい。"
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host ("{0,2}: {1}" -f ($i + 1), $candidates[$i].display_name)
        }
        $sel = $null
        do {
            $sel = Read-Host "番号 (1-$($candidates.Count)) or 'q' to quit"
            if ($sel -eq 'q') { return $null }
        } while (-not ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $candidates.Count))
        return $candidates[[int]$sel - 1]
    }
    hidden static [object[]] _InvokeOverpassQuery([string]$query) {
        try {
            $result = [GPXDocumentFactory]::InvokeWithRetry(
                { Invoke-RestMethod -Uri ([GPXDocumentFactory]::OverpassUrl) -Method Post -Body $query -Headers ([GPXDocumentFactory]::ApiHeaders) },
                5,
                3
            )
            return @($result.elements)
        }
        catch {
            Write-Warning "Overpass失敗: $($_.Exception.Message)"; return @()
        }
    }
    hidden static [long] _GetOverpassAreaId([double]$lat, [double]$lon) {
        $q = @"
[out:json];
is_in($lat,$lon)->.a;
rel(pivot.a)["boundary"="administrative"]["admin_level"~"^[6-8]$"];
out body;
"@
        $rels = [GPXDocumentFactory]::_InvokeOverpassQuery($q)
        if (-not $rels) { return $null }
        $rel = $rels | Sort-Object { [int]$_.tags.admin_level } -Descending | Select-Object -First 1
        if (-not $rel) { return $null }
        return 3600000000 + $rel.id
    }
    hidden static [void] _AddTownsToDoc(
        [GPXDocument]$gpx,
        [object[]]$towns,
        [bool]$resolveAddr
    ) {
        if (-not $towns) { 
            Write-Host "ℹ️ 町字追加: towns が空のため処理なし"
            return 
        }

        $total = $towns.Count
        $added = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        # 住所解決ありなら並列関数を呼ぶ、なしならダミーを作る
        $resolved = if ($resolveAddr) {
            [GPXDocumentFactory]::ResolveLocations($towns)
        }
        else {
            $towns | ForEach-Object { @{ item = $_; result = $null } }
        }

        foreach ($r in $resolved) {
            $t = $r.item
            if (-not $t.tags.name) { continue }

            $info = @{
                lat     = [double]$t.lat
                lon     = [double]$t.lon
                name    = $t.tags.name
                desc    = $t.tags.name
                address = $null
            }
            if ($r.result) {
                if ($r.result.display_name) { $info.desc = $r.result.display_name }
                if ($r.result.address) { $info.address = $r.result.address }
            }

            $gpx.AppendTrkPt($info)
            $added++
        }

        $gpx.UpdateStats()
        $sw.Stop()

        # ログ出力
        Write-Host ("✅ 町字追加 完了: 入力={0}, 追加={1}, 時間={2}ms (住所解決={3})" -f $total, $added, $sw.ElapsedMilliseconds, $resolveAddr) -ForegroundColor Green
    }
    hidden static [object[]] _InvokeNominatimSearch([string]$Keyword, [int]$Limit) {
        $enc = [System.Web.HttpUtility]::UrlEncode($Keyword)
        $uri = "{0}?q={1}&format=json&addressdetails=1&limit={2}&countrycodes=jp" -f [GPXDocumentFactory]::NominatimSearchUrl, $enc, $Limit
        try {
            $res = Invoke-RestMethod -Uri $uri -Method Get -Headers ([GPXDocumentFactory]::ApiHeaders)
            return @($res)
        }
        catch {
            Write-Warning "Nominatim Search失敗: $($_.Exception.Message)"
            return @()
        }
    }
    #endregion
}
