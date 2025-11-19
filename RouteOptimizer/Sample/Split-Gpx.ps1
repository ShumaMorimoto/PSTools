using module RouteOptimizer

param (
    [Parameter(Mandatory)]
    [string]$InputFile,

    [double]$DistanceKm = 0.0,
    [int]$PointLimit = 40
)

if (-not (Test-Path $InputFile)) {
    Write-Error "❌ ファイルが見つかりません: $InputFile"
    exit 1
}

# GPX読み込み
[xml]$gpx = Get-Content $InputFile
$trkpts = $gpx.gpx.trk.trkseg.trkpt
if (-not $trkpts -or $trkpts.Count -lt 2) {
    Write-Warning "trkptが不足しています。分割できません。"
    exit 1
}

# 分割（Split-Route使用）
$routes = Split-Route -Places $trkpts -DistanceKm $DistanceKm -PointLimit $PointLimit

# 出力準備
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$outputDir = [System.IO.Path]::GetDirectoryName($InputFile)
$segmentIndex = 1

foreach ($trkptNodes in $routes) {
    # 新しいGPX構造を作成
    $newGpx = [xml]$gpx.OuterXml
    $trkseg = $newGpx.gpx.trk.trkseg
    $trkseg.RemoveAll()

    foreach ($pt in $trkptNodes) {
        $trkseg.AppendChild($newGpx.ImportNode($pt, $true)) | Out-Null
    }

    # 統計情報追加
    $newGpx = Add-GpxStats -GpxXml $newGpx

    # トラック名設定
    $trkNameNode = $newGpx.gpx.trk.SelectSingleNode("name")
    if (-not $trkNameNode) {
        $trkNameNode = $newGpx.CreateElement("name")
        $newGpx.gpx.trk.AppendChild($trkNameNode) | Out-Null
    }
    $trkNameNode.InnerText = "Segment $segmentIndex"

    # ファイル保存
    $filename = [System.IO.Path]::Combine($outputDir, ("{0}-{1:D2}.gpx" -f $baseName, $segmentIndex))
    $newGpx.Save($filename)

    # 統計表示
    $distanceRounded = [math]::Round($newGpx.gpx.trk.extensions.stats.totalDistanceKm, 2)
    $pointCount = $newGpx.gpx.trk.extensions.stats.pointCount
    Write-Host "✅ 出力: $filename （距離: $distanceRounded km　拠点：$pointCount）" -ForegroundColor Cyan

    $segmentIndex++
}