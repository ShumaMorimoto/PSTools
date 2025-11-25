class GPXDocument : System.Xml.XmlDocument {
    hidden static [System.Xml.XmlNamespaceManager] $NamespaceManager

    static [void] Initialize([System.Xml.XmlDocument]$doc) {
        if (-not [GPXDocument]::NamespaceManager -and $doc.DocumentElement) {
            $mgr = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
            $mgr.AddNamespace("gpx", $doc.DocumentElement.NamespaceURI)
            [GPXDocument]::NamespaceManager = $mgr
        }
    }

    GPXDocument() { }

    GPXDocument($rep) {
        $creator = "GPXDocument クラス"
        $this.AppendChild($this.CreateXmlDeclaration("1.0", "UTF-8", $null))
        $gpxRoot = $this.CreateElement("gpx", "http://www.topografix.com/GPX/1/1")
        $gpxRoot.SetAttribute("version", "1.1")
        $gpxRoot.SetAttribute("creator", $creator)
        $this.AppendChild($gpxRoot)

        $metadataNode = $this.CreateMetadataElement($rep, $gpxRoot.NamespaceURI)
        if ($metadataNode) { $gpxRoot.AppendChild($metadataNode) | Out-Null }

        $trk = $this.CreateElement("trk", $gpxRoot.NamespaceURI)
        $trkseg = $this.CreateElement("trkseg", $gpxRoot.NamespaceURI)
        $trk.AppendChild($trkseg) | Out-Null
        $gpxRoot.AppendChild($trk) | Out-Null

        [GPXDocument]::Initialize($this)
    }

    static [GPXDocument] Load([string]$path) {
        $doc = [GPXDocument]::new()
        $doc.Load($path)
        $root = $doc.DocumentElement
        if (-not $root.HasAttribute("version")) { $root.SetAttribute("version", "1.1") }
        if (-not $root.HasAttribute("xmlns")) { $root.SetAttribute("xmlns", "http://www.topografix.com/GPX/1/1") }
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
            $trkpt = $this.CreateTrkPtElement($info, $this.DocumentElement.NamespaceURI)
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
            $totalDistance += Get-Distance($trackPoints[$i], $trackPoints[$i + 1])
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
            $extensionsNode = $this.CreateElement("extensions", $this.DocumentElement.NamespaceURI)
            $trackNode.AppendChild($extensionsNode) | Out-Null
        }
        else {
            $existingStatsNode = $extensionsNode.SelectSingleNode("gpx:stats", [GPXDocument]::NamespaceManager)
            if ($existingStatsNode) { $extensionsNode.RemoveChild($existingStatsNode) | Out-Null }
        }
        $statsNode = $this.CreateElement("stats", $this.DocumentElement.NamespaceURI)

        $distanceNode = $this.CreateElement("totalDistanceKm", $this.DocumentElement.NamespaceURI)
        $distanceNode.InnerText = ("{0:F2}" -f $stats.TotalDistanceKm)
        $statsNode.AppendChild($distanceNode) | Out-Null

        $countNode = $this.CreateElement("pointCount", $this.DocumentElement.NamespaceURI)
        $countNode.InnerText = "$($stats.PointCount)"
        $statsNode.AppendChild($countNode) | Out-Null

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
    hidden [System.Xml.XmlElement] CreateMetadataElement($rep, $ns) {
        $meta = $this.CreateElement("metadata", $ns)
        $timeNode = $this.CreateElement("time", $ns)
        $timeNode.InnerText = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $meta.AppendChild($timeNode) | Out-Null
        if ($rep.name) {
            $nameNode = $this.CreateElement("name", $ns)
            $nameNode.InnerText = $rep.name
            $meta.AppendChild($nameNode) | Out-Null
        }
        if ($rep.desc) {
            $descNode = $this.CreateElement("desc", $ns)
            $descNode.InnerText = $rep.desc
            $meta.AppendChild($descNode) | Out-Null
        }
        if ($rep.address) {
            $meta.AppendChild($this.CreateExtensionsElement($rep.address, $ns)) | Out-Null
        }
        return $meta
    }
    hidden [System.Xml.XmlElement] CreateExtensionsElement($data, $ns) {
        $ext = $this.CreateElement("extensions", $ns)
        foreach ($prop in $data.PSObject.Properties) {
            if ($prop.Value) {
                $child = $this.CreateElement($prop.Name, $ns)
                $child.InnerText = $prop.Value
                $ext.AppendChild($child) | Out-Null
            }
        }
        return $ext
    }
    hidden [System.Xml.XmlElement] CreateTrkPtElement($info, $ns) {
        $trkpt = $this.CreateElement("trkpt", $ns)
        if ($info.lat) { $trkpt.SetAttribute("lat", $info.lat) }
        if ($info.lon) { $trkpt.SetAttribute("lon", $info.lon) }
        if ($info.name) {
            $nameNode = $this.CreateElement("name", $ns)
            $nameNode.InnerText = $info.name
            $trkpt.AppendChild($nameNode) | Out-Null
        }
        if ($info.desc) {
            $descNode = $this.CreateElement("desc", $ns)
            $descNode.InnerText = $info.desc
            $trkpt.AppendChild($descNode) | Out-Null
        }
        if ($info.address) {
            $trkpt.AppendChild($this.CreateExtensionsElement($info.address, $ns)) | Out-Null
        }
        return $trkpt
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
        $results = [GPXDocumentFactory]::_InvokeNominatimSearch($Keyword)
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
            $enriched | Add-Member -NotePropertyName townname -Value $town -Force
            $enriched | Add-Member -NotePropertyName keyword -Value $Keyword -Force
            $enriched | Add-Member -NotePropertyName timestamp -Value $now -Force
            $gpx.AppendTrkPt(@{
                    lat     = [double]$res.lat
                    lon     = [double]$res.lon
                    name    = $res.name ?? $town
                    desc    = $res.display_name
                    address = $enriched
                })
        }
        $gpx.UpdateStats()
        return $gpx
    }

    #endregion

    #region Public Helpers

    static [object[]] ResolveKeyword([string]$Keyword, [bool]$MunicipalityOnly) {
        $params = @{ q = $Keyword; format = 'json'; addressdetails = 1; limit = 7; zoom = 12 }
        try {
            $result = Invoke-RestMethod -Uri ([GPXDocumentFactory]::NominatimSearchUrl) -Method Get -Body $params -Headers ([GPXDocumentFactory]::ApiHeaders)
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

    hidden static [object] InvokeWithRetry([scriptblock]$act, [int]$MaxRetry = 5, [int]$DelaySec = 3) {
        $last = $null
        for ($i = 1; $i -le $MaxRetry; $i++) {
            try { return $act.Invoke() }
            catch { $last = $_; if ($i -lt $MaxRetry) { Start-Sleep -Seconds $DelaySec } }
        }
        if ($last) { throw $last }
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
        do {
            $sel = Read-Host "番号 (1-$($candidates.Count)) or 'q' to quit"
            if ($sel -eq 'q') { return $null }
        } while (-not ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $candidates.Count))
        return $candidates[[int]$sel - 1]
    }
    hidden static [object[]] _InvokeOverpassQuery([string]$query) {
        try {
            $result = [GPXDocumentFactory]::InvokeWithRetry({ Invoke-RestMethod -Uri ([GPXDocumentFactory]::OverpassUrl) -Method Post -Body $query -Headers ([GPXDocumentFactory]::ApiHeaders) })
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
            $info = @{lat = [double]$t.lat; lon = [double]$t.lon; name = $t.tags.name; desc = $t.tags.name; address = $null }
            if ($resolveAddr) {
                Start-Sleep -Milliseconds 250
                $rev = [GPXDocumentFactory]::ResolveLocation($info.lat, $info.lon)
                if ($rev) { $info.desc = $rev.desc; $info.address = $rev.address }
            }
            $gpx.AppendTrkPt($info)
        }
        $gpx.UpdateStats()
    }
    hidden static [object[]] _InvokeNominatimSearch([string]$Keyword) {
        $enc = [System.Web.HttpUtility]::UrlEncode($Keyword)
        $uri = "https://nominatim.openstreetmap.org/search?q=$enc&format=json&addressdetails=1&limit=50&countrycodes=jp"
        try {
            $res = [GPXDocumentFactory]::InvokeWithRetry({
                    Invoke-RestMethod -Uri $uri -Method Get -Headers ([GPXDocumentFactory]::ApiHeaders)
                })
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
