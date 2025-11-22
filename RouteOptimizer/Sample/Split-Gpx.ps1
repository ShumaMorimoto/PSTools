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

try {
    # ① GPX読み込み
    $gpxDoc = [GPXDocument]::Load($InputFile)
    $trkpts = $gpxDoc.GetTrkPt()
    if (-not $trkpts -or $trkpts.Count -lt 2) {
        Write-Warning "trkptが不足しています。分割できません。"
        exit 1
    }

    # ② 分割（Split-Places使用）
    $routes = Split-Places -Places $trkpts -DistanceKm $DistanceKm -PointLimit $PointLimit

    # ③ 出力準備
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $outputDir = [System.IO.Path]::GetDirectoryName($InputFile)
    $segmentIndex = 1

    foreach ($trkptNodes in $routes) {
        # 新しいGPXDocumentを作成（元の構造をコピー）
        $newDoc = [GPXDocument]::LoadXml($gpxDoc.OuterXml)

        # 拠点を再設定（内部でUpdateStatsが呼ばれる）
        $newDoc.SetTrkPt($trkptNodes)

        # トラック名設定
        $newDoc.SetTrkName("分割 $segmentIndex")

        # ファイル保存
        $filename = [System.IO.Path]::Combine($outputDir, ("{0}-{1:D2}.gpx" -f $baseName, $segmentIndex))
        $newDoc.Save($filename)

        # 統計表示（GetStatsを利用）
        $stats = $newDoc.GetStats()
        $distanceRounded = $stats.TotalDistanceKm
        $pointCount = $stats.PointCount

        Write-Host "✅ 出力: $filename （距離: $distanceRounded km　拠点：$pointCount）" -ForegroundColor Cyan

        $segmentIndex++
    }
}
catch {
    Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
}