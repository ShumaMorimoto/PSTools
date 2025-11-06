using module RouteOptimizer

param (
    [string]$InputFile,
    [double]$Distance = 10.0,
    [int]$Count = 0
)

if (-not (Test-Path $InputFile)) {
    Write-Host "ファイルが見つかりません: $InputFile"
    exit
}

[xml]$gpx = Get-Content $InputFile
#$segments = Split-Gpx -GpxXml $gpx -DistanceKm 10.0
$segments = Split-Gpx -GpxXml $gpx -PointLimit 50



# 出力処理
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$segmentIndex = 1

foreach ($xml in $segments) {

    $outputDir = [System.IO.Path]::GetDirectoryName($InputFile)
    $filename = [System.IO.Path]::Combine($outputDir, ("{0}-{1:D2}.gpx" -f $baseName, $segmentIndex))
    $xml.Save($filename)

    $distanceRounded = [math]::Round($xml.gpx.trk.extensions.stats.totalDistanceKm, 2)
    $pointCount = $xml.gpx.trk.extensions.stats.pointCount
    Write-Host "出力: $filename （距離: $distanceRounded km　拠点：$pointCount）"

    $segmentIndex++
}

