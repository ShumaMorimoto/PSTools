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
        return [GPXDocument]::FromKmlXml($xml)
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

    static [string] GetTownName([System.Xml.XmlElement]$trkpt) {
        return [GPXDocument]::GetTownName($trkpt, 1)
    }
    static [string] GetTownName([System.Xml.XmlElement]$trkpt, [int]$level = 1) {
        if (-not $trkpt.extensions) { return "Unknown" }

        # 値を文字列化（XmlElement対応）
        function Get-Text($x) {
            if ($x -is [System.Xml.XmlElement]) { return $x.InnerText }
            else { return $x }
        }

        $province = Get-Text $trkpt.extensions.province
        $county = Get-Text $trkpt.extensions.county
        $city = Get-Text $trkpt.extensions.city
        $town = Get-Text $trkpt.extensionstown
        $village = Get-Text $trkpt.extensions.village
        $suburb = Get-Text $trkpt.extensions.suburb
        $quarter = Get-Text $trkpt.extensions.quarter
        $neigh = Get-Text $trkpt.extensions.neighbourhood

        switch ($level) {
            0 { return ($province + $county + $city + $town + $village + $suburb + $quarter + $neigh) }
            1 { return ($county + $city + $town + $village) }
            2 {
                if ($suburb) { return $suburb }
                elseif ($county -or $town -or $village) { return ($county + $town + $village) }
                elseif ($city) { return $city }
                else { return "Unknown" }
            }
            3 { return ($county + $city + $town + $village + $suburb + $quarter + $neigh) }
            default { return "Unknown" }
        }
        return "Unknown"
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