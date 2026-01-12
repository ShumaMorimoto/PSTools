param (
    [string]$InputFile,
    [double]$Distance = 10.0,
    [int]$Count = 0
)

function Get-DistanceKm {
    param (
        [double]$lat1, [double]$lon1,
        [double]$lat2, [double]$lon2
    )
    $R = 6371
    $dLat = [math]::PI / 180 * ($lat2 - $lat1)
    $dLon = [math]::PI / 180 * ($lon2 - $lon1)
    $a = [math]::Pow([math]::Sin($dLat / 2), 2) +
    [math]::Cos([math]::PI / 180 * $lat1) *
    [math]::Cos([math]::PI / 180 * $lat2) *
    [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

if (-not (Test-Path $InputFile)) {
    Write-Host "ファイルが見つかりません: $InputFile"
    exit
}

[xml]$gpx = Get-Content $InputFile
$trkpts = $gpx.gpx.trk.trkseg.trkpt

# 全体距離を計算
$totalDistance = 0.0
for ($i = 0; $i -lt $trkpts.Count - 1; $i++) {
    $totalDistance += Get-DistanceKm $trkpts[$i].lat $trkpts[$i].lon $trkpts[$i + 1].lat $trkpts[$i + 1].lon
}

# 分割距離の決定
if ($Count -gt 0) {
    $targetDistance = $totalDistance / $Count
}
else {
    $targetDistance = $Distance
}

# 分割処理
$segments = @()
$currentSegment = @()
$currentDistance = 0.0

for ($i = 0; $i -lt $trkpts.Count - 1; $i++) {
    $pt1 = $trkpts[$i]
    $pt2 = $trkpts[$i + 1]

    $currentSegment += $pt1
    $dist = Get-DistanceKm $pt1.lat $pt1.lon $pt2.lat $pt2.lon
    $currentDistance += $dist

    if ($currentDistance -ge $targetDistance) {
        $currentSegment += $pt2
        $segments += @{ Points = $currentSegment; Distance = $currentDistance }
        $currentSegment = @()
        $currentDistance = 0.0
    }
}

if ($currentSegment.Count -gt 0) {
    $currentSegment += $trkpts[-1]
    $segments += @{ Points = $currentSegment; Distance = $currentDistance }
}

# 出力処理
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$segmentIndex = 1

foreach ($segment in $segments) {
    $trkptNodes = $segment.Points
    $xml = New-GpxFromTrkpt -TrkptNodes $trkptNodes -TrackName "Segment $segmentIndex"

    $outputDir = [System.IO.Path]::GetDirectoryName($InputFile)
    $filename = [System.IO.Path]::Combine($outputDir, ("{0}-{1:D2}.gpx" -f $baseName, $segmentIndex))
    $xml.Save($filename)

    $distanceRounded = [math]::Round($segment.Distance, 2)
    Write-Host "出力: $filename （距離: $distanceRounded km）"

    $segmentIndex++
}