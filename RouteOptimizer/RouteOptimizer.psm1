#モジュールルートの設定
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─── DLL 読み込み ───
if (Test-Path "$PSScriptRoot\lib") {
    Get-ChildItem "$PSScriptRoot\lib\*.dll" | ForEach-Object {
        Add-Type -Path $_.FullName
    }
}

# ─── クラス定義 ───
class GPXDocument : System.Xml.XmlDocument {
    hidden static [System.Xml.XmlNamespaceManager] $NsMgr

    static [void] Initialize([System.Xml.XmlDocument]$doc) {
        if (-not [GPXDocument]::NsMgr -and $doc.DocumentElement) {
            [GPXDocument]::NsMgr = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
            [GPXDocument]::NsMgr.AddNamespace("gpx", $doc.DocumentElement.NamespaceURI)
        }
    }

    GPXDocument() { }
    GPXDocument([string]$Creator, [string]$Name) {
        $xmlDecl = $this.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $this.AppendChild($xmlDecl) | Out-Null

        $gpx = $this.CreateElement("gpx", "http://www.topografix.com/GPX/1/1")
        $gpx.SetAttribute("version", "1.1")
        $gpx.SetAttribute("creator", $Creator)
        $this.AppendChild($gpx) | Out-Null

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

    [System.Xml.XmlElement[]] GetTrkPt() {
        return @($this.SelectNodes("//gpx:trk/gpx:trkseg/gpx:trkpt", [GPXDocument]::NsMgr))
    }

    [void] SetTrkPt([System.Xml.XmlElement[]]$points) {
        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NsMgr)
        $trkseg.RemoveAll()
        foreach ($pt in $points) {
            $trkseg.AppendChild($this.ImportNode($pt, $true)) | Out-Null
        }
        $this.UpdateStats()
    }
    [void] AddTrkPtNode([System.Xml.XmlElement]$trkptNode) {
        if (-not $trkptNode) { return }

        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NsMgr)
        if (-not $trkseg) { return }

        # ImportNodeで安全にコピーして追加
        $imported = $this.ImportNode($trkptNode, $true)
        $trkseg.AppendChild($imported) | Out-Null

        # 統計情報更新
        $this.UpdateStats()
    }
    [void] AddTrkPt([double]$lat, [double]$lon, [string]$name, [string]$desc, [object]$addr) {
        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NsMgr)

        $trkpt = $this.CreateElement("trkpt", $this.DocumentElement.NamespaceURI)
        $trkpt.SetAttribute("lat", $lat.ToString())
        $trkpt.SetAttribute("lon", $lon.ToString())

        if ($name) {
            $nameNode = $this.CreateElement("name", $this.DocumentElement.NamespaceURI)
            $nameNode.InnerText = $name
            $trkpt.AppendChild($nameNode) | Out-Null
        }

        if ($desc) {
            $descNode = $this.CreateElement("desc", $this.DocumentElement.NamespaceURI)
            $descNode.InnerText = $desc
            $trkpt.AppendChild($descNode) | Out-Null
        }

        if ($addr) {
            # $addr が XmlNode の場合（extensionsノードを想定）
            if ($addr -is [System.Xml.XmlNode]) {
                # そのままインポートして追加
                $extNode = $this.ImportNode($addr, $true)
                $trkpt.AppendChild($extNode) | Out-Null
            }
            else {
                # ハッシュテーブルやPSObjectの場合
                $extNode = $this.CreateElement("extensions", $this.DocumentElement.NamespaceURI)
                foreach ($key in $addr.PSObject.Properties.Name) {
                    $val = $addr.$key
                    if ($val) {
                        $child = $this.CreateElement($key, $this.DocumentElement.NamespaceURI)
                        $child.InnerText = $val
                        $extNode.AppendChild($child) | Out-Null
                    }
                }
                $trkpt.AppendChild($extNode) | Out-Null
            }
        }

        $trkseg.AppendChild($trkpt) | Out-Null
    }
    [hashtable] GetStats() {
        $trkpts = $this.GetTrkPt()
        if (-not $trkpts -or $trkpts.Count -lt 2) {
            return @{TotalDistance = 0; PointCount = $trkpts.Count }
        }

        $totalDistance = 0.0
        for ($i = 0; $i -lt $trkpts.Count - 1; $i++) {
            $totalDistance += Get-Distance $trkpts[$i] $trkpts[$i + 1]
        }

        $pointCount = $trkpts.Count

        return @{
            TotalDistanceKm = [math]::Round($totalDistance, 2)
            PointCount      = $pointCount
        }
    }
    [void] UpdateStats() {
        # GetStatsで統計情報を取得
        $stats = $this.GetStats()
        if (-not $stats -or $stats.Count -eq 0) {
            Write-Warning "統計情報が取得できませんでした。"
            return
        }

        $trkNode = $this.SelectSingleNode("//gpx:trk", [GPXDocument]::NsMgr)

        # extensionsノードを探す／作成
        $extNode = $trkNode.SelectSingleNode("gpx:extensions", [GPXDocument]::NsMgr)
        if (-not $extNode) {
            $extNode = $this.CreateElement("extensions", $this.DocumentElement.NamespaceURI)
            $trkNode.AppendChild($extNode) | Out-Null
        }
        else {
            # 既存のstatsノードを削除
            $existingStats = $extNode.SelectSingleNode("gpx:stats", [GPXDocument]::NsMgr)
            if ($existingStats) { $extNode.RemoveChild($existingStats) | Out-Null }
        }

        # 新しいstatsノードを作成
        $statsNode = $this.CreateElement("stats", $this.DocumentElement.NamespaceURI)

        $distNode = $this.CreateElement("totalDistanceKm", $this.DocumentElement.NamespaceURI)
        $distNode.InnerText = ("{0:F2}" -f $stats.TotalDistanceKm)
        $statsNode.AppendChild($distNode) | Out-Null

        $countNode = $this.CreateElement("pointCount", $this.DocumentElement.NamespaceURI)
        $countNode.InnerText = "$($stats.PointCount)"
        $statsNode.AppendChild($countNode) | Out-Null

        $extNode.AppendChild($statsNode) | Out-Null
    }

    [void] SetTrkName([string]$trkName) {
        $trkNode = $this.SelectSingleNode("//gpx:trk", [GPXDocument]::NsMgr)
        if (-not $trkNode) { return }

        $nameNode = $trkNode.SelectSingleNode("gpx:name", [GPXDocument]::NsMgr)
        if (-not $nameNode) {
            $nameNode = $this.CreateElement("name", $this.DocumentElement.NamespaceURI)
            $trkNode.AppendChild($nameNode) | Out-Null
        }
        $nameNode.InnerText = $trkName
    }

    [string] ToXmlString() {
        return $this.OuterXml
    }
}

# ─── 関数読み込み ───
foreach ($folder in @('Common', 'Extensions', 'Private', 'Public')) {
    if (Test-Path "$PSScriptRoot\$folder") {
        Get-ChildItem "$PSScriptRoot\$folder\*.ps1" | ForEach-Object {
            . $_.FullName
        }
    }
}

# ─── 公開関数 ───
$publicFunctions = @()
if (Test-Path "$PSScriptRoot\Public") {
    $publicFunctions = Get-ChildItem "$PSScriptRoot\Public\*.ps1" | ForEach-Object {
        [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    }
}
Export-ModuleMember -Function $publicFunctions

# ─── モジュール初期化 ───
Enable-ModuleSettings
