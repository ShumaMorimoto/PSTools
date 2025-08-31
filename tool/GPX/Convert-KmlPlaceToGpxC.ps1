# ========================
# KML → TSP最適化 → GPX出力
# ========================

# 距離計算（Haversine法）
function Get-Distance {
    param ($p1, $p2)
    $R = 6371.0
    $dLat = [math]::PI / 180 * ($p2.lat - $p1.lat)
    $dLon = [math]::PI / 180 * ($p2.lon - $p1.lon)
    $a = [math]::Pow([math]::Sin($dLat / 2), 2) +
         [math]::Cos([math]::PI / 180 * $p1.lat) *
         [math]::Cos([math]::PI / 180 * $p2.lat) *
         [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

# Greedy法によるTSP近似解（最後に始点を追加）
function Solve-TSP-Greedy {
    param (
        [Parameter(Mandatory)]
        [array]$Points
    )

    $visited = @()
    $remaining = @($Points)
    $start = $remaining[0]
    $current = $start
    $visited += $current
    $remaining = $remaining | Where-Object { $_ -ne $current }

    while ($remaining.Count -gt 0) {
        $next = $remaining | Sort-Object { Get-Distance $current $_ } | Select-Object -First 1
        $visited += $next
        $remaining = $remaining | Where-Object { $_ -ne $next }
        $current = $next
    }

    $visited += $start
    return $visited
}

# KML → GPX変換
function Convert-KmlPlaceToGpx {
    param (
        [xml]$KmlXml
    )

    $points = @()
    foreach ($placemark in $KmlXml.kml.Document.Folder.Placemark) {
        if ($placemark.Point.coordinates -match "(-?\d+(\.\d+)?),(-?\d+(\.\d+)?)(?:,.*)?") {
            $lon = [double]$matches[1]
            $lat = [double]$matches[3]
            $name = $placemark.name
            $points += @{lon = $lon; lat = $lat; name = $name }
        }
    }

    if ($points.Count -eq 0) {
        throw "KMLファイルに有効なPlace座標が見つかりませんでした。"
    }

    $sortedPoints = Solve-TSP-Greedy $points

    $gpxNs = "http://www.topografix.com/GPX/1/1"
    $gpxDoc = New-Object System.Xml.XmlDocument
    $decl = $gpxDoc.CreateXmlDeclaration("1.0", "UTF-8", $null)
    $gpxDoc.AppendChild($decl) | Out-Null

    $gpxRoot = $gpxDoc.CreateElement("gpx")
    $gpxRoot.SetAttribute("version", "1.1")
    $gpxRoot.SetAttribute("creator", "KML-GPX-TSP-Converter")
    $gpxRoot.SetAttribute("xmlns", $gpxNs)
    $gpxDoc.AppendChild($gpxRoot) | Out-Null

    $trk = $gpxDoc.CreateElement("trk")
    $nameNode = $gpxDoc.CreateElement("name")
    $nameNode.InnerText = "TSP Optimized Route"
    $trk.AppendChild($nameNode) | Out-Null

    $trkseg = $gpxDoc.CreateElement("trkseg")

    foreach ($point in $sortedPoints) {
        $trkpt = $gpxDoc.CreateElement("trkpt")
        $trkpt.SetAttribute("lat", $point.lat)
        $trkpt.SetAttribute("lon", $point.lon)

        $ptName = $gpxDoc.CreateElement("name")
        $ptName.InnerText = $point.name
        $trkpt.AppendChild($ptName) | Out-Null

        $trkseg.AppendChild($trkpt) | Out-Null
    }

    $trk.AppendChild($trkseg) | Out-Null
    $gpxRoot.AppendChild($trk) | Out-Null

    return $gpxDoc
}

# ========================
# 実行パート（引数対応）
# ========================

# デフォルトパス
$defaultPath = "C:\Users\shuma\Downloads\米沢茶屋.kml"

# 引数からパス取得（なければデフォルト）
$KmlInputPath = if ($args.Count -ge 1) { $args[0] } else { $defaultPath }

if (-not (Test-Path $KmlInputPath)) {
    Write-Host "❌ ファイルが見つかりません: $KmlInputPath"
    exit 1
}

try {
    [xml]$kml = Get-Content $KmlInputPath -Raw
    $gpxDoc = Convert-KmlPlaceToGpx $kml
    $outputPath = Join-Path (Split-Path $KmlInputPath) "converted.gpx"
    $gpxDoc.Save($outputPath)
    Write-Host "✅ GPXファイルを保存しました: $outputPath"
} catch {
    Write-Host "❌ エラー: $_"
}