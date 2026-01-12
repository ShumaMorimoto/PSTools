using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.dedup.gpx')"
)

try {
    # ① GPX読み込み
    $gpxDoc = [GPXDocument]::Load($InputGpxPath)

    # ② 拠点取得
    $trkpts = $gpxDoc.GetTrkPts()

    # ③ 重複削除（lat, lon をキーにユニーク化）
    $seen = @{}
    $deduped = foreach ($pt in $trkpts) {
        $key = "$($pt.lat),$($pt.lon)"
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $pt
        }
    }

    # ④ 再構築
    $gpxDoc.SetTrkPts($deduped)

    # ⑤ 保存
    $gpxDoc.Save($OutputGpxPath)
    Write-Host "✅ 重複拠点を削除したGPXファイルを保存しました: $OutputGpxPath" -ForegroundColor Green
}
catch {
    Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
}