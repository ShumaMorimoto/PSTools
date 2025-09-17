using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.optimized.gpx')"
)

# ① GPX読み込み
$xml = [xml](Get-Content $InputGpxPath)
$ns = @{ gpx = "http://www.topografix.com/GPX/1/1" }

# ② TrackName取得
$trackName = $xml.gpx.trk.name
if (-not $trackName) {
    $trackName = "Optimized Track"
    Write-Warning "⚠️ TrackNameが見つかりません。デフォルト名を使用します。"
}

# ③ <trkpt> ノード抽出
$trkpts = $xml.SelectNodes("//gpx:trkpt", $ns)
if (-not $trkpts -or $trkpts.Count -eq 0) {
    Write-Error "❌ GPXファイルにトラックポイントが見つかりません。"
    return
}

# ④ 最適化実行（XmlElementのまま渡す）
$optimized = Optimize-Route -Places $trkpts

# ⑤ ConvertTo-Gpx にそのまま渡す（変換なし）
$gpxXml = $optimized | ConvertTo-Gpx -TrackName $trackName

# ⑥ 保存
try {
    $gpxXml.Save($OutputGpxPath)
    Write-Host "✅ 最適化GPXファイルを保存しました: $OutputGpxPath" -ForegroundColor Green
} catch {
    Write-Error "❌ GPXファイル保存に失敗: $($_.Exception.Message)"
}