using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.updated.gpx')"
)

# ① GPX読み込み
[xml] $gpx = Get-Content $InputGpxPath

# ② 拠点取得
$trkpts = $gpx.gpx.trk.trkseg.trkpt

# 並び替え

$newtrkpts = ($trkpts | Get-Place)

# 再構築
$trkseg = $gpx.gpx.trk.trkseg
$trkseg.RemoveAll()
foreach ($pt in $newtrkpts) {
    $trkseg.AppendChild($gpx.ImportNode($pt, $true)) | Out-Null
}

# 統計情報追加
$gpx = Add-GpxStats -GpxXml $gpx

# 保存
try {
    $gpx.Save($OutputGpxPath)
    Write-Host "✅ 拠点情報更新GPXファイルを保存しました: $OutputGpxPath" -ForegroundColor Green
}
catch {
    Write-Error "❌ GPXファイル保存に失敗: $($_.Exception.Message)"
}