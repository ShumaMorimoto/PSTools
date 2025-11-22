using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.updated.gpx')"
)

try {
    # ① GPX読み込み
    $gpxDoc = [GPXDocument]::Load($InputGpxPath)

    # ② 拠点取得
    $trkpts = $gpxDoc.GetTrkPt()

    # ③ 拠点情報付加
    $newtrkpts = ($trkpts | Get-PlaceInfo)

    # ④ 再構築
    $gpxDoc.SetTrkPt($newtrkpts)

    # ⑥ 保存
    $gpxDoc.Save($OutputGpxPath)
    Write-Host "✅ 最適化GPXファイルを保存しました: $OutputGpxPath" -ForegroundColor Green
}
catch {
    Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
}

