using module RouteOptimizer

param(
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath
)

try {
    # ① GPX読み込み
    $gpxDoc = [GPXDocument]::Load($InputGpxPath)

    # ② trkptタグを取得
    $trkpts = $gpxDoc.GetTrkpts()

    if (-not $trkpts) {
        Write-Warning "⚠️ GPXファイルにtrkptタグが見つかりません。"
        return
    }

    # ③ Index / Name / lat / lon をリスト化
    $index = 0
    $list = foreach ($pt in $trkpts) {
        $index++
        [PSCustomObject]@{
            Index = $index
            Name  = $pt.name    # <name>タグがある場合
            lat   = $pt.lat
            lon   = $pt.lon
        }
    }

    # ④ 表形式で表示
    $list | Format-Table Index, Name, lat, lon -AutoSize
}
catch {
    Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
}