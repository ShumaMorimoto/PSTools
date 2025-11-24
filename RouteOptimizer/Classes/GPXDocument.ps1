class GPXDocument : System.Xml.XmlDocument {
    hidden static [System.Xml.XmlNamespaceManager] $NamespaceManager

    # 初期化: 名前空間マネージャを設定
    static [void] Initialize([System.Xml.XmlDocument]$doc) {
        if (-not [GPXDocument]::NamespaceManager -and $doc.DocumentElement) {
            [GPXDocument]::NamespaceManager = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
            [GPXDocument]::NamespaceManager.AddNamespace("gpx", $doc.DocumentElement.NamespaceURI)
        }
    }

    GPXDocument() { }

    GPXDocument([string]$creator, [hashtable]$rep) {
        $xmlDeclaration = $this.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $this.AppendChild($xmlDeclaration) | Out-Null

        $gpxRoot = $this.CreateElement("gpx", "http://www.topografix.com/GPX/1/1")
        $gpxRoot.SetAttribute("version", "1.1")
        $gpxRoot.SetAttribute("creator", $creator)
        $this.AppendChild($gpxRoot) | Out-Null

        # metadata
        $metadataNode = $this.CreateElement("metadata", $gpxRoot.NamespaceURI)

        $timeNode = $this.CreateElement("time", $gpxRoot.NamespaceURI)
        $timeNode.InnerText = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $metadataNode.AppendChild($timeNode) | Out-Null

        if ($rep["name"]) {
            $nameNode = $this.CreateElement("name", $gpxRoot.NamespaceURI)
            $nameNode.InnerText = $rep["name"]
            $metadataNode.AppendChild($nameNode) | Out-Null
        }
        if ($rep["desc"]) {
            $descNode = $this.CreateElement("desc", $gpxRoot.NamespaceURI)
            $descNode.InnerText = $rep["desc"]
            $metadataNode.AppendChild($descNode) | Out-Null
        }
        if ($rep["address"]) {
            $extNode = $this.CreateElement("extensions", $this.DocumentElement.NamespaceURI)
            foreach ($key in $rep["address"].PSObject.Properties.Name) {
                $val = $rep["address"].$key
                if ($val) {
                    $child = $this.CreateElement($key, $this.DocumentElement.NamespaceURI)
                    $child.InnerText = $val
                    $extNode.AppendChild($child) | Out-Null
                }
            }
            $metadataNode.AppendChild($extNode) | Out-Null
        }
        $gpxRoot.AppendChild($metadataNode) | Out-Null

        # trk/trkseg
        $trackNode = $this.CreateElement("trk", $gpxRoot.NamespaceURI)
        $trackSegmentNode = $this.CreateElement("trkseg", $gpxRoot.NamespaceURI)
        $gpxRoot.AppendChild($trackNode) | Out-Null
        $trackNode.AppendChild($trackSegmentNode) | Out-Null

        [GPXDocument]::Initialize($this)
    }

    # コンストラクタ: 名前だけ指定
    GPXDocument([string]$creator, [string]$name) {
        $xmlDeclaration = $this.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $this.AppendChild($xmlDeclaration) | Out-Null

        $gpxRoot = $this.CreateElement("gpx", "http://www.topografix.com/GPX/1/1")
        $gpxRoot.SetAttribute("version", "1.1")
        $gpxRoot.SetAttribute("creator", $creator)
        $this.AppendChild($gpxRoot) | Out-Null

        # metadata生成（名前のみ）
        $metadataNode = $this.BuildMetadata($name, $null)
        $gpxRoot.AppendChild($metadataNode) | Out-Null

        # 空のtrk/trkseg
        $trackNode = $this.CreateElement("trk", $gpxRoot.NamespaceURI)
        $trackSegmentNode = $this.CreateElement("trkseg", $gpxRoot.NamespaceURI)
        $gpxRoot.AppendChild($trackNode) | Out-Null
        $trackNode.AppendChild($trackSegmentNode) | Out-Null

        [GPXDocument]::Initialize($this)
    }

    # GPXファイルをロード
    static [GPXDocument] Load([string]$path) {
        $doc = [GPXDocument]::new()
        $doc.Load($path)

        # ルート要素を取得
        $root = $doc.DocumentElement

        # version がなければ追加
        if (-not $root.HasAttribute("version")) {
            $root.SetAttribute("version", "1.1")
        }
        # xmlns がなければ追加
        if (-not $root.HasAttribute("xmlns")) {
            $root.SetAttribute("xmlns", "http://www.topografix.com/GPX/1/1")
        }

        [GPXDocument]::Initialize($doc)
        return $doc
    }

    # GPX文字列をロード
    static [GPXDocument] LoadXml([string]$xml) {
        $doc = [GPXDocument]::new()
        $doc.LoadXml($xml)
        [GPXDocument]::Initialize($doc)
        return $doc
    }

    # trkpt一覧を取得
    [System.Xml.XmlElement[]] GetTrkPts() {
        return @($this.SelectNodes("//gpx:trk/gpx:trkseg/gpx:trkpt", [GPXDocument]::NamespaceManager))
    }

    # trkptを追加（単一または複数）
    [void] AppendTrkPt([hashtable]$info) {
        # 名前空間マネージャを利用
        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NamespaceManager)
        if (-not $trkseg) { return }

        $trkpt = $this.CreateElement("trkpt", $this.DocumentElement.NamespaceURI)
        $trkpt.SetAttribute("lat", $info["lat"])
        $trkpt.SetAttribute("lon", $info["lon"])

        if ($info["name"]) {
            $nameNode = $this.CreateElement("name", $this.DocumentElement.NamespaceURI)
            $nameNode.InnerText = $info["name"]
            $trkpt.AppendChild($nameNode) | Out-Null
        }
        if ($info["desc"]) {
            $descNode = $this.CreateElement("desc", $this.DocumentElement.NamespaceURI)
            $descNode.InnerText = $info["desc"]
            $trkpt.AppendChild($descNode) | Out-Null
        }
        if ($info["address"]) {
            $extNode = $this.CreateElement("extensions", $this.DocumentElement.NamespaceURI)
            foreach ($key in $info["address"].PSObject.Properties.Name) {
                $val = $info["address"].$key
                if ($val) {
                    $child = $this.CreateElement($key, $this.DocumentElement.NamespaceURI)
                    $child.InnerText = $val
                    $extNode.AppendChild($child) | Out-Null
                }
            }
            $trkpt.AppendChild($extNode) | Out-Null
        }       
        $trkseg.AppendChild($trkpt) | Out-Null
    }

    # trkptを一括設定（既存を置換）
    [void] SetTrkPts([System.Xml.XmlElement[]]$trackPoints) {
        $trackSegmentNode = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NamespaceManager)
        $trackSegmentNode.RemoveAll()
        foreach ($point in $trackPoints) {
            $trackSegmentNode.AppendChild($this.ImportNode($point, $true)) | Out-Null
        }
        $this.UpdateStats()
    }

    # 統計情報を取得
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

    # 統計情報を更新（trk/extensionsに保存）
    [void] UpdateStats() {
        $stats = $this.GetStats()
        if (-not $stats) { return }
        $trackNode = $this.SelectSingleNode("//gpx:trk", [GPXDocument]::NamespaceManager)
        $extensionsNode = $trackNode.SelectSingleNode("gpx:extensions", [GPXDocument]::NamespaceManager)
        if (-not $extensionsNode) {
            $extensionsNode = $this.CreateElement("extensions", $this.DocumentElement.NamespaceURI)
            $trackNode.AppendChild($extensionsNode) | Out-Null
        }
        else {
            $existingStatsNode = $extensionsNode.SelectSingleNode("gpx:stats", [GPXDocument]::NamespaceManager)
            if ($existingStatsNode) { $extensionsNode.RemoveChild($existingStatsNode) | Out-Null }
        }

        # 統計ノード生成
        $statsNode = $this.CreateElement("stats", $this.DocumentElement.NamespaceURI)

        $distanceNode = $this.CreateElement("totalDistanceKm", $this.DocumentElement.NamespaceURI)
        $distanceNode.InnerText = ("{0:F2}" -f $stats.TotalDistanceKm)
        $statsNode.AppendChild($distanceNode) | Out-Null

        $countNode = $this.CreateElement("pointCount", $this.DocumentElement.NamespaceURI)
        $countNode.InnerText = "$($stats.PointCount)"
        $statsNode.AppendChild($countNode) | Out-Null

        $extensionsNode.AppendChild($statsNode) | Out-Null
    }

    # trkの名前を設定
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

    # XML文字列として出力
    [string] ToXmlString() {
        return $this.OuterXml
    }
}
