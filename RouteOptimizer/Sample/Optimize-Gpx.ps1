using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.optimized.gpx')"
)

try {
    # ① GPX読み込み
    $gpxDoc = [GPXDocument]::Load($InputGpxPath)

    # ② 拠点取得
    $trkpts = $gpxDoc.GetTrkPts()

    # ③ 並び替え
    $optimized = Optimize-AreaRoute -Places $trkpts

    # ④ 再構築
    $gpxDoc.SetTrkPts($optimized)

    # ⑥ 保存
    $gpxDoc.Save($OutputGpxPath)
    Write-Host "✅ 最適化GPXファイルを保存しました: $OutputGpxPath" -ForegroundColor Green
}
catch {
    Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
}