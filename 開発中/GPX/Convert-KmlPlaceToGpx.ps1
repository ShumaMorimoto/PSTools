function Get-Distance {
    param ($p1, $p2)
    $dx = [math]::Abs($p1.lon - $p2.lon)
    $dy = [math]::Abs($p1.lat - $p2.lat)
    return [math]::Sqrt($dx * $dx + $dy * $dy)
}

function Solve-TSP-Greedy {
    param (
        [Parameter(Mandatory)]
        [array]$Points  # @{lat=..., lon=...} の配列
    )

    $visited = @()
    $remaining = $Points.Clone()
    $current = $remaining[0]
    $visited += $current
    $remaining = $remaining | Where-Object { $_ -ne $current }

    while ($remaining.Count -gt 0) {
        $next = $remaining | Sort-Object { Get-Distance $current $_ } | Select-Object -First 1
        $visited += $next
        $remaining = $remaining | Where-Object { $_ -ne $next }
        $current = $next
    }

    return $visited
}

function Convert-KmlRouteToGpx {
    param (
        [xml]$KmlXml
    )

    $lines = $Kmlxml.kml.Document.Folder.Placemark.Point.coordinates
    $points = @()
    foreach ($line in $lines) {
        if ($line -match "(-?\d+(\.\d+)?),(-?\d+(\.\d+)?)(?:,.*)?") {
            $lon = $matches[1]
            $lat = $matches[3]
            $points += @{lon = $lon; lat = $lat }
        }
    }
    $newpoints = Solve-TSP-Greedy($points)

    $gpxNs = "http://www.topografix.com/GPX/1/1"
    $gpxDoc = New-Object System.Xml.XmlDocument
    $gpxRoot = $gpxDoc.CreateElement("gpx")
    $gpxRoot.SetAttribute("version", "1.1")
    $gpxRoot.SetAttribute("creator", "KML-GPX-RouteConverter")
    $gpxRoot.SetAttribute("xmlns", $gpxNs)
    $null = $gpxDoc.AppendChild($gpxRoot)

    $trk = $gpxDoc.CreateElement("trk")
    $trkseg = $gpxDoc.CreateElement("trkseg")

    foreach ($point in $newpoints) {
        $trkpt = $gpxDoc.CreateElement("trkpt")
        $trkpt.SetAttribute("lat", $point.lat)
        $trkpt.SetAttribute("lon", $point.lon)
        $trkpt.SetAttribute("muitiRoute", "1")
        $null = $trkseg.AppendChild($trkpt)
    }

    $null = $trk.AppendChild($trkseg)
    $null = $gpxRoot.AppendChild($trk)

    return $gpxDoc
}

$GpxInputPath = "C:\Users\shuma\Downloads\米沢茶屋.kml"

[xml]$kml = Get-Content $GpxInputPath -Raw
$doc = Convert-KmlRouteToGpx($kml)

$outputPath = Join-Path (Split-Path $GpxInputPath) "converted.gpx"

Write-Host "💾 出力中: $outputPath"
$doc.Save($outputPath)
Write-Host "✅ 変換完了"
