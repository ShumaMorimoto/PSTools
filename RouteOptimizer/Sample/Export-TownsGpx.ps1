using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$Keyword,

    [Parameter()]
    [string]$TrackName = "$Keywordの周遊",

    [Parameter()]
    [string]$OutputPath = "【周遊】$Keyword.gpx"
)

# ① 町字一覧を取得
$gpxXml = Get-CityTowns -Keyword $Keyword
if (-not $gpxXml) {
    Write-Warning "❌ 町字が取得できませんでした。GPXファイルは生成されません。"
    return
}

# ② 拠点取得
$trkpts = $gpxXml.GetTrkPt()

# 並び替え
$optimized = Optimize-AreaRoute -Places $trkpts

# 再構築
$gpxXml.SetTrkPt($optimized)

# ④ ファイルに保存
try {
    $gpxXml.Save($OutputPath)
    Write-Host "✅ GPXファイルを保存しました: $OutputPath" -ForegroundColor Green
} catch {
    Write-Error "❌ GPXファイルの保存に失敗しました: $($_.Exception.Message)"
}
