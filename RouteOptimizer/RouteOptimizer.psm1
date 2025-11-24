#モジュールルートの設定
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─── DLL 読み込み ───
if (Test-Path "$PSScriptRoot\lib") {
    Get-ChildItem "$PSScriptRoot\lib\*.dll" | ForEach-Object {
        Add-Type -Path $_.FullName
    }
}

# ─── クラス定義 ───

# Windows Forms と Drawing をロード
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
