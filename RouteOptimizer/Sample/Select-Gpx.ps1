using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.selected.gpx')"
)

try {
    # ① GPX読み込み
    $gpxDoc = [GPXDocument]::Load($InputGpxPath)

    # ② 拠点取得
    $trkpts = $gpxDoc.GetTrkPt()

    # ③ 並び替え
    $selected = Select-Places -Places $trkpts

    # ④ 再構築
    $gpxDoc.SetTrkPt($selected)

    # ⑥ 保存
    $gpxDoc.Save($OutputGpxPath)
    Write-Host "✅ 最適化GPXファイルを保存しました: $OutputGpxPath" -ForegroundColor Green
}
catch {
    Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
}