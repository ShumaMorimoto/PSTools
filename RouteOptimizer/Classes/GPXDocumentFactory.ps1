Class GPXDocumentFactory {
    static [string]$NominatimUrl = "https://nominatim.openstreetmap.org/search"
    static [string]$ReverseUrl = "https://nominatim.openstreetmap.org/reverse"
    static [string]$OverpassUrl = "https://overpass-api.de/api/interpreter"
    static [hashtable]$Headers = @{ "User-Agent" = "RouteOptimizer-Client" }

    static [hashtable] ResolveKeyword([string]$Keyword, [bool]$MunicipalityOnly) {
        $params = @{ q = $Keyword; format = "json"; addressdetails = 1; limit = 7; zoom = 12 }

        try {
            $results = Invoke-RestMethod `
                -Uri ([GPXDocumentFactory]::NominatimUrl) -Method Get -Body $params -Headers  ([GPXDocumentFactory]::Headers)
        }
        catch {
            Write-Error "Nominatim検索失敗: $_"
            return $null
        }

        if ($MunicipalityOnly) {
            # 自治体レベルに限定
            $results = $results | Where-Object { $_.addresstype -in @("city", "town", "village", "suburb") }
        }
        # 候補なし
        if (-not $results) {
            Write-Warning "候補が見つかりませんでした。"
            return $null
        }

        # 単一なら採用、複数なら選択
        $target = if ($results.Count -eq 1) {
            $results[0]
        }
        else {
            Write-Host "候補一覧："
            for ($i = 0; $i -lt $results.Count; $i++) {
                Write-Host (" {0,2}: {1}" -f ($i + 1), $results[$i].display_name)
            }
            $sel = $null
            do {
                $sel = Read-Host "番号を選択 (1-$($results.Count)) または qで中止"
                if ($sel -eq 'q') { return $null }
            } while (-not ($sel -match '^\d+$' -and $sel -ge 1 -and $sel -le $results.Count))
            $results[[int]$sel - 1]
        }

        return @{
            lat     = [double]$target.lat
            lon     = [double]$target.lon
            name    = $target.name
            desc    = $target.display_name
            address = $target.address
        }
    }

    static [hashtable] ResolveLocation([double]$lat, [double]$lon) {
        $url = "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1"
        try {
            $res = Invoke-RestMethod -Uri $url -Headers  ([GPXDocumentFactory]::Headers)
            return @{
                lat     = $lat
                lon     = $lon
                name    = $res.name
                desc    = $res.display_name
                address = $res.address
            }
        }
        catch {
            Write-Warning "ResolveLocation失敗: $_"
            return $null
        }
    }
   
    static [GPXDocument] FromCityTowns([string]$Keyword) {
        return [GPXDocumentFactory]::FromCityTowns($Keyword, $false)
    }
    
    static [GPXDocument] FromCityTowns([string]$Keyword, [bool]$resolveAddress = $false) {
        # キーワード判定
        if ($Keyword -match '^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$') {
            $parts = $Keyword -split ','
            $lat = [double]$parts[0].Trim()
            $lon = [double]$parts[1].Trim()
            $rev = [GPXDocumentFactory]::ResolveLocation($lat, $lon)
        }
        else {
            $rev = [GPXDocumentFactory]::ResolveKeyword($Keyword, $true)
        }
        # 代表点リバース → metadata用
        if (-not $rev) { return $null }

        # GPXDocインスタンス化
        $doc = [GPXDocument]::new("RouteOptimizer", $rev)

        # Overpassで町字ノード取得
        $queryRel = @"
[out:json];
is_in($($rev.lat),$($rev.lon))->.a;
rel(pivot.a)["boundary"="administrative"]["admin_level"~"^[6-8]$"];
out body;
"@
        $relResult = Invoke-WithRetry {
            Invoke-RestMethod -Uri ([GPXDocumentFactory]::OverpassUrl) -Method Post -Body $queryRel -Headers ([GPXDocumentFactory]::Headers)
        } -MaxRetry 5 -DelaySec 3
        $relation = $relResult.elements | Sort-Object { [int]$_.tags.admin_level } -Descending | Select-Object -First 1
        $areaId = 3600000000 + $relation.id

        $queryTowns = @"
[out:json];
area($areaId)->.searchArea;
node(area.searchArea)["place"];
out body;
"@
        $townResult = Invoke-WithRetry {
            Invoke-RestMethod -Uri ([GPXDocumentFactory]::OverpassUrl) -Method Post -Body $queryTowns -Headers ([GPXDocumentFactory]::Headers)
        } -MaxRetry 5 -DelaySec 3

        $towns = $townResult.elements | Where-Object { $_.tags.name -and ($_.tags.place -in @('neighbourhood', 'quarter')) }

        foreach ($el in $towns) {
            $tLat = [double]$el.lat
            $tLon = [double]$el.lon
            $name = $el.tags.name

            if ($resolveAddress) {
                $revT = [GPXDocumentFactory]::ResolveLocation($tLat, $tLon)
                $desc = $revT.display_name
                $addr = $revT.address
            }
            else {
                $desc = $name; $addr = $null
            }

            $info = @{
                lat     = $tLat
                lon     = $tLon
                name    = $name
                desc    = $desc
                address = $addr
            }
            $doc.AppendTrkPt($info)
        }
        $doc.UpdateStats()
        return $doc
    }

    static [GPXDocument] FromAreaTowns(
        [string]$Keyword,
        [double]$RadiusKm
    ) {
        return [GPXDocumentFactory]::FromAreaTowns($Keyword, $RadiusKm, $false)
    }

    static [GPXDocument] FromAreaTowns(
        [string]$Keyword,
        [double]$RadiusKm = 2,
        [bool]$resolveAddress = $false
    ) {
        # キーワード判定
        if ($Keyword -match '^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$') {
            $parts = $Keyword -split ','
            $lat = [double]$parts[0].Trim()
            $lon = [double]$parts[1].Trim()
        }
        else {
            # ランドマーク含めて解決（絞らない）
            $coord = ResolveKeywordToCoordinate $Keyword $false
            if (-not $coord) { return $null }
            $lat = $coord.lat; $lon = $coord.lon
        }

        # 代表点リバース → metadata用
        $rev = [GPXDocumentFactory]::ResolveLocation($lat, $lon)
        if (-not $rev) { return $null }

        # GPXDocインスタンス化
        $doc = [GPXDocument]::new("RouteOptimizer", $rev)

        $radius = [int]($RadiusKm * 1000)

        # 範囲内ノード（リトライ）
        $query = @"
[out:json];
node(around:$radius,$lat,$lon)[place];
out body;
"@
        try {
            $res = Invoke-WithRetry {
                Invoke-RestMethod -Uri ([GPXDocumentFactory]::OverpassUrl) -Method Post -Body $query -Headers ([GPXDocumentFactory]::Headers)
            } -MaxRetry 5 -DelaySec 3
        }
        catch {
            Write-Warning "範囲ノード取得失敗: $_"
            return $doc
        }

        $towns = $res.elements | Where-Object { $_.tags.name -and ($_.tags.place -in @('neighbourhood', 'quarter')) }

        foreach ($el in $towns) {
            $tLat = [double]$el.lat
            $tLon = [double]$el.lon
            $name = $el.tags.name

            if ($resolveAddress) {
                $revT = [GPXDocumentFactory]::ResolveLocation($tLat, $tLon)
                $desc = $revT.display_name
                $addr = $revT.address
            }
            else {
                $desc = $name; $addr = $null
            }

            $info = @{
                lat     = $tLat
                lon     = $tLon
                name    = $name
                desc    = $desc
                address = $addr
            }
            $doc.AppendTrkPt($info)
        }
        $doc.UpdateStats()
        return $doc
    }
}