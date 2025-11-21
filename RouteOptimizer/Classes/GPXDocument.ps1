class GPXDocument : System.Xml.XmlDocument {
    hidden static [System.Xml.XmlNamespaceManager] $NsMgr

    static [void] Initialize([System.Xml.XmlDocument]$doc) {
        if (-not [GPXDocument]::NsMgr -and $doc.DocumentElement) {
            [GPXDocument]::NsMgr = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
            [GPXDocument]::NsMgr.AddNamespace("gpx", $doc.DocumentElement.NamespaceURI)
        }
    }
    
    GPXDocument() {
        # 空のコンストラクタ（Load 用）
        # DocumentElement がまだないので Initialize は後で呼ばれる
    }

    GPXDocument([string]$Creator, [string]$Name) {
        # 新規生成用コンストラクタ
        $xmlDecl = $this.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $this.AppendChild($xmlDecl) | Out-Null

        $gpx = $this.CreateElement("gpx", "http://www.topografix.com/GPX/1/1")
        $gpx.SetAttribute("version", "1.1")
        $gpx.SetAttribute("creator", $Creator)
        $this.AppendChild($gpx) | Out-Null

        # metadata
        $metadata = $this.CreateElement("metadata", $gpx.NamespaceURI)
        $timeNode = $this.CreateElement("time", $gpx.NamespaceURI)
        $timeNode.InnerText = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $metadata.AppendChild($timeNode) | Out-Null
        if ($Name) {
            $nameNode = $this.CreateElement("name", $gpx.NamespaceURI)
            $nameNode.InnerText = $Name
            $metadata.AppendChild($nameNode) | Out-Null
        }
        $gpx.AppendChild($metadata) | Out-Null

        $trk = $this.CreateElement("trk", $gpx.NamespaceURI)
        $trkseg = $this.CreateElement("trkseg", $gpx.NamespaceURI)
        $gpx.AppendChild($trk) | Out-Null
        $trk.AppendChild($trkseg) | Out-Null

        # Initialize 呼び出し
        [GPXDocument]::Initialize($this)
    }

    static [GPXDocument] Load([string]$path) {
        $doc = [GPXDocument]::new()
        $doc.Load($path)
        [GPXDocument]::Initialize($doc)
        return $doc
    }

    static [GPXDocument] LoadXml([string]$xml) {
        $doc = [GPXDocument]::new()
        $doc.LoadXml($xml)
        [GPXDocument]::Initialize($doc)
        return $doc
    }

    [System.Xml.XmlNodeList] GetTrkPt() {
        return $this.SelectNodes("//gpx:trk/gpx:trkseg/gpx:trkpt", [GPXDocument]::NsMgr)
    }

    [void] SetTrkPt([System.Xml.XmlElement[]]$points) {
        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NsMgr)
        $trkseg.RemoveAll()
        foreach ($pt in $points) {
            $trkseg.AppendChild($this.ImportNode($pt, $true)) | Out-Null
        }
    }

    [void] UpdateStats() {
        $trkpts = $this.GetTrkPt()
        if (-not $trkpts -or $trkpts.Count -lt 2) {
            Write-Warning "trkptが不足しています。統計情報は追加されません。"
            return
        }

        $totalDistance = 0.0
        for ($i = 0; $i -lt $trkpts.Count - 1; $i++) {
            $totalDistance += Get-Distance $trkpts[$i] $trkpts[$i + 1]
        }

        $pointCount = $trkpts.Count
        $trkNode = $this.SelectSingleNode("//gpx:trk", [GPXDocument]::NsMgr)

        # 統計情報追加
        $extNode = $trkNode.SelectSingleNode("gpx:extensions", [GPXDocument]::NsMgr)
        if (-not $extNode) {
            $extNode = $this.CreateElement("extensions", $this.DocumentElement.NamespaceURI)
            $trkNode.AppendChild($extNode) | Out-Null
        }
        else {
            $existingStats = $extNode.SelectSingleNode("gpx:stats", [GPXDocument]::NsMgr)
            if ($existingStats) { $extNode.RemoveChild($existingStats) | Out-Null }
        }

        $statsNode = $this.CreateElement("stats", $this.DocumentElement.NamespaceURI)
        $distNode = $this.CreateElement("totalDistanceKm", $this.DocumentElement.NamespaceURI)
        $distNode.InnerText = ("{0:F2}" -f $totalDistance)
        $statsNode.AppendChild($distNode) | Out-Null

        $countNode = $this.CreateElement("pointCount", $this.DocumentElement.NamespaceURI)
        $countNode.InnerText = "$pointCount"
        $statsNode.AppendChild($countNode) | Out-Null

        $extNode.AppendChild($statsNode) | Out-Null
    }

    [string] ToXmlString() {
        return $this.OuterXml
    }
}