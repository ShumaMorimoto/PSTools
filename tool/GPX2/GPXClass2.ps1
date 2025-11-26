class GPXDocument : System.Xml.XmlDocument {
    hidden static $creator = "GPXDocument クラス"
    hidden static [string] $GpxNamespace = "http://www.topografix.com/GPX/1/1"
    hidden static [System.Xml.XmlNamespaceManager] $NamespaceManager

    # 初期化: 名前空間マネージャを設定
    static [void] Initialize([System.Xml.XmlDocument]$doc) {
        if (-not [GPXDocument]::NamespaceManager -and $doc.DocumentElement) {
            [GPXDocument]::NamespaceManager = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
            [GPXDocument]::NamespaceManager.AddNamespace("gpx", $doc.DocumentElement.NamespaceURI)
        }
    }

    GPXDocument() { 
    }

    GPXDocument($rep) {
        # rep が文字列なら name にラップ、nullなら空ハッシュに
        if ($rep -is [string]) { $rep = @{ name = $rep } }
        elseif (-not $rep) { $rep = @{} }

        $this.AppendChild($this.CreateXmlDeclaration("1.0", "UTF-8", $null))

        # metadata 用 info を事前加工
        $metaInfo = [pscustomobject]@{
            time       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            name       = $rep.name
            desc       = $rep.desc
            extensions = $rep.address
        }
        # gpx のルート info
        $rootInfo = [pscustomobject]@{
            version  = "1.1"
            creator  = [GPXDocument]::creator
            metadata = $metaInfo
            trk      = @{ trkseg = $null }  # 空タグを info 展開で生成
        }

        $gpxRoot = $this.CreateElementFromPSO("gpx", $rootInfo, @("version", "creator"))
        $gpxRoot.SetAttribute("xmlns", [GPXDocument]::GpxNamespace)
        $this.AppendChild($gpxRoot)

        [GPXDocument]::Initialize($this)
    }

    static [GPXDocument] LoadKmlFile([string]$path) {
        if (-not (Test-Path $path)) {
            throw "KMLファイルが見つかりません: $path"
        }
        $xml = [xml](Get-Content $path -Raw)
        return [GPXDocumentFactory]::FromKmlXml($xml)
    }
    static [GPXDocument] FromKmlXml([System.Xml.XmlDocument]$xmlDoc) {
        $placemarks = $xmlDoc.SelectNodes("//Placemark")
        $gpx = [GPXDocument]::new(@{
                name = "Converted from KML"
                desc = "KML source document"
            })

        foreach ($pm in $placemarks) {
            $name = $pm.SelectSingleNode("name")?.InnerText
            $coordText = $pm.SelectSingleNode("Point/coordinates")?.InnerText
            if (-not $coordText) { continue }

            $parts = $coordText.Trim() -split ","
            $lon = [double]$parts[0]
            $lat = [double]$parts[1]

            $gpx.AppendTrkPt(@{
                    lat  = $lat
                    lon  = $lon
                    name = $name
                    desc = $pm.SelectSingleNode("description")?.InnerText
                })
        }
        $gpx.UpdateStats()
        return $gpx
    }

    static [GPXDocument] Load([string]$path) {
        $doc = [GPXDocument]::new()
        $doc.Load($path)
        $root = $doc.DocumentElement
        if (-not $root.HasAttribute("version")) { $root.SetAttribute("version", "1.1") }
        if (-not $root.HasAttribute("xmlns")) { $root.SetAttribute("xmlns", [GPXDocument]::GpxNamespace) }
        [GPXDocument]::Initialize($doc)

        return $doc
    }
    static [GPXDocument] LoadXml([string]$xml) {
        $doc = [GPXDocument]::new()
        $doc.LoadXml($xml)
        [GPXDocument]::Initialize($doc)

        return $doc
    }

    [System.Xml.XmlElement[]] GetTrkPts() {
        return @($this.SelectNodes("//gpx:trk/gpx:trkseg/gpx:trkpt", [GPXDocument]::NamespaceManager))
    }

    [void] AppendTrkPt($info) {
        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NamespaceManager)
        if (-not $trkseg) { return }
        if ($info -is [System.Xml.XmlElement] -and $info.LocalName -eq "trkpt") {
            $trkseg.AppendChild($this.ImportNode($info, $true)) | Out-Null
        }
        else {
            # info を組み立てて PSO展開
            $info = [pscustomobject]@{
                lat        = $info.lat
                lon        = $info.lon
                name       = $info.name
                desc       = $info.desc
                extensions = $info.address
            }
            $trkpt = $this.CreateElementFromPSO("trkpt", $info, @("lat", "lon"))
            if ($trkpt) { $trkseg.AppendChild($trkpt) | Out-Null }
        }
    }

    [void] SetTrkPts([System.Xml.XmlElement[]]$pts) {
        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NamespaceManager)
        $trkseg.RemoveAll()
        foreach ($pt in $pts) {
            $trkseg.AppendChild($this.ImportNode($pt, $true))
        }
    }

    [string] ToXmlString() { return $this.OuterXml }

    # ------- 統計情報などメソッド -------
    [hashtable] GetStats() {
        $trackPoints = $this.GetTrkPts()
        if (-not $trackPoints -or $trackPoints.Count -lt 2) {
            return @{ TotalDistanceKm = 0; PointCount = $trackPoints.Count }
        }
        $totalDistance = 0.0
        for ($i = 0; $i -lt $trackPoints.Count - 1; $i++) {
            $totalDistance += Get-Distance $trackPoints[$i] $trackPoints[$i + 1]
        }
        return @{
            TotalDistanceKm = [math]::Round($totalDistance, 2)
            PointCount      = $trackPoints.Count
        }
    }

    [void] UpdateStats() {
        $stats = $this.GetStats()
        if (-not $stats) { return }

        $trackNode = $this.SelectSingleNode("//gpx:trk", [GPXDocument]::NamespaceManager)
        if (-not $trackNode) { return }

        $extensionsNode = $trackNode.SelectSingleNode("gpx:extensions", [GPXDocument]::NamespaceManager)
        if (-not $extensionsNode) {
            # CreateElementFromPSOでextensionsノードを生成
            $extensionsNode = $this.CreateElementFromPSO("extensions")
            $trackNode.AppendChild($extensionsNode) | Out-Null
        }
        else {
            $existingStatsNode = $extensionsNode.SelectSingleNode("gpx:stats", [GPXDocument]::NamespaceManager)
            if ($existingStatsNode) { $extensionsNode.RemoveChild($existingStatsNode) | Out-Null }
        }

        # statsノードをPSO展開で生成
        $statsInfo = [pscustomobject]@{
            totalDistanceKm = ("{0:F2}" -f $stats.TotalDistanceKm)
            pointCount      = "$($stats.PointCount)"
        }

        $statsNode = $this.CreateElementFromPSO("stats", $statsInfo)
        $extensionsNode.AppendChild($statsNode) | Out-Null
    }

    [void] SetTrkName([string]$trackName) {
        $trackNode = $this.SelectSingleNode("//gpx:trk", [GPXDocument]::NamespaceManager)
        if (-not $trackNode) { return }
        $nameNode = $trackNode.SelectSingleNode("gpx:name", [GPXDocument]::NamespaceManager)
        if (-not $nameNode) {
            $nameNode = $this.CreateElement("name", $this.DocumentElement.NamespaceURI)
            $trackNode.AppendChild($nameNode) | Out-Null
        }
        $nameNode.InnerText = $trackName
    }

    # ------- 以下エレメント生成ヘルパ -------
    hidden [System.Xml.XmlElement] CreateElementFromPSO([string]$tagName) {
        return $this.CreateElementFromPSO($tagName, $null, @())
    }
    hidden [System.Xml.XmlElement] CreateElementFromPSO([string]$tagName, [object]$info) {
        return $this.CreateElementFromPSO($tagName, $info, @())
    }
    hidden [System.Xml.XmlElement] CreateElementFromPSO(
        [string]$elementName,
        [object]$pso,
        [string[]]$attributes
    ) {
        $elem = $this.CreateElement($elementName, [GPXDocument]::GpxNamespace)

        if (-not $pso) { return $elem }

        if ($pso -is [hashtable]) {
            foreach ($kv in $pso.GetEnumerator()) {
                $name = $kv.Key
                $value = $kv.Value
                $this.ProcessPSOProperty($elem, $name, $value, $attributes, [GPXDocument]::GpxNamespace)
            }
        }
        else {
            foreach ($prop in $pso.PSObject.Properties) {
                $name = $prop.Name
                $value = $prop.Value
                $this.ProcessPSOProperty($elem, $name, $value, $attributes, [GPXDocument]::GpxNamespace)
            }
        }

        return $elem
    }

    hidden [void] ProcessPSOProperty(
        [System.Xml.XmlElement]$parent,
        [string]$name,
        [object]$value,
        [string[]]$attributes,
        [string]$ns
    ) {
        if ($attributes -contains $name) {
            $parent.SetAttribute($name, "$($value ?? '')")
        }
        else {
            if ($null -eq $value) {
                $child = $this.CreateElement($name, $ns)
                $parent.AppendChild($child) | Out-Null
            }
            elseif ($value -is [hashtable] -or $value -is [PSCustomObject]) {
                $child = $this.CreateElementFromPSO($name, $value)
                $parent.AppendChild($child) | Out-Null
            }
            else {
                $child = $this.CreateElement($name, $ns)
                $child.InnerText = "$value"
                $parent.AppendChild($child) | Out-Null
            }
        }
    }
}

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
            $town = [GPXDocumentFactory]::_GenTownName($addr)
            $enriched = $addr.PSObject.Copy()
            $enriched | Add-Member -NotePropertyName "townname" -NotePropertyValue $town -Force
            $enriched | Add-Member -NotePropertyName "keyword" -NotePropertyValue $Keyword -Force
            $enriched | Add-Member -NotePropertyName "timstamp" -NotePropertyValue $now -Force
            $gpx.AppendTrkPt(@{
                    lat     = [double]$res.lat
                    lon     = [double]$res.lon
                    name    = $res.name ?? $town
                    desc    = $res.display_name
                    address = $enriched
                })
        }
        return $gpx
    }
    static [GPXDocument] EnrichTrkPts([GPXDocument]$gpx) {
        if (-not $gpx) { throw "GPXDocumentが指定されていません。" }

        $trkpts = $gpx.GetTrkPts()
        if (-not $trkpts -or $trkpts.Count -eq 0) { return $null}

        foreach ($pt in $trkpts) {
            # 住所取得（必要に応じてレート制限のために短いスリープ）
            Start-Sleep -Milliseconds 250
            $rev = [GPXDocumentFactory]::ResolveLocation($pt.lat, $pt.lon)
            if (-not $rev -or -not $rev.address) { continue }

            # (1) extensions を置換（既存があれば削除 → 新規作成）
            $extNodeOld = $pt.SelectSingleNode("gpx:extensions", [GPXDocument]::NamespaceManager)
            if ($extNodeOld) { $pt.RemoveChild($extNodeOld) | Out-Null }

            $extNode = $gpx.CreateElementFromPSO("extensions", @{extensions = $rev.address})
            # 完成した extensions を trkpt に追加
            $pt.AppendChild($extNode) | Out-Null

            # (2) name が無ければ補完（既存は尊重）
            $nameNode = $pt.SelectSingleNode("gpx:name", [GPXDocument]::NamespaceManager)
            if (-not $nameNode) {
                $nameNode = $gpx.CreateElement("name", [GPXDocument]::GpxNamespace)
                $pt.AppendChild($nameNode) | Out-Null
            }
            if ([string]::IsNullOrWhiteSpace($nameNode.InnerText) -and $rev.name) {
                $nameNode.InnerText = $rev.name
            }

            # (3) desc が無ければ補完（既存は尊重）
            $descNode = $pt.SelectSingleNode("gpx:desc", [GPXDocument]::NamespaceManager)
            if (-not $descNode) {
                $descNode = $gpx.CreateElement("desc", [GPXDocument]::GpxNamespace)
                $pt.AppendChild($descNode) | Out-Null
            }
            if ([string]::IsNullOrWhiteSpace($descNode.InnerText) -and $rev.desc) {
                $descNode.InnerText = $rev.desc
            }
        }
        # 距離は座標から計算されるため、最後に統計更新
        $gpx.UpdateStats()
    }
    #endregion

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
        $uri = "{0}?lat={1}&lon={2}&format=json&addressdetails=1" -f [GPXDocumentFactory]::NominatimReverseUrl, $lat, $lon
        try {
            $res = Invoke-RestMethod -Uri $uri -Headers ([GPXDocumentFactory]::ApiHeaders)
            return @{ lat = $lat; lon = $lon; name = $res.name; desc = $res.display_name; address = $res.address }
        }
        catch {
            Write-Warning "逆引き失敗: $($_.Exception.Message)"; return $null
        }
    }

    #endregion

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
    hidden static [void] _AddTownsToDoc([GPXDocument]$gpx, [object[]]$towns, [bool]$resolveAddr) {
        if (-not $towns) { return }
        foreach ($t in $towns) {
            if (-not $t.tags.name) { continue }
            $info = @{lat = [double]$t.lat; lon = [double]$t.lon; name = $t.tags.name; desc = $t.tags.name; extensions = $null }
            if ($resolveAddr) {
                Start-Sleep -Milliseconds 250
                $rev = [GPXDocumentFactory]::ResolveLocation($info.lat, $info.lon)
                if ($rev) { $info.desc = $rev.desc; $info.extensions = $rev.address }
            }
            $gpx.AppendTrkPt($info)
        }
        $gpx.UpdateStats()
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
    hidden static [string] _GenTownName([object]$addr) {
        if (-not $addr) { return "Unknown" }
        $townArea = $addr.quarter ?? $addr.neighbourhood ?? $addr.suburb ?? $null
        $municipality = $addr.city ?? $addr.town ?? $addr.village ?? $null
        $county = $addr.county; $suburb = $addr.suburb
        if ($municipality -and $townArea) {
            if ($addr.city -and $suburb) { return "$municipality$suburb$townArea" }
            elseif ($addr.town -and $county) { return "$county$municipality$townArea" }
            else { return "$municipality$townArea" }
        }
        elseif ($municipality) {
            if ($county) { return "$county$municipality" }
            else { return "$municipality" }
        }
        else { return "Unknown" }
    }
    #endregion
}
