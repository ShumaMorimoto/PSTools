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
$towns = Get-CityTowns -Keyword $Keyword
if (-not $towns) {
    Write-Warning "❌ 町字が取得できませんでした。GPXファイルは生成されません。"
    return
}

# ② GA最適化
$route = Optimize-AreaRoute $towns

# ③ GPXオブジェクトを生成
$gpxXml = $route | ConvertTo-Gpx -TrackName $TrackName

# ④ ファイルに保存
try {
    $gpxXml.Save($OutputPath)
    Write-Host "✅ GPXファイルを保存しました: $OutputPath" -ForegroundColor Green
} catch {
    Write-Error "❌ GPXファイルの保存に失敗しました: $($_.Exception.Message)"
}
