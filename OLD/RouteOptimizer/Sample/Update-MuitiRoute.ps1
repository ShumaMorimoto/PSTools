using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,
    [Parameter()]
    [int]$muitiRoute = 1
)

process {
    try {
        # ① GPX読み込み
        $gpxDoc = [GPXDocument]::Load($InputGpxPath)

        # ② trkptタグに multiLocation="1" を追加
        foreach ($trkpt in $gpxDoc.GetTrkpts()) {
            # 既に属性がある場合は上書き、なければ追加
            if ($trkpt.Attributes["muitiRoute"]) {
                $trkpt.Attributes["muitiRoute"].Value = $muitiRoute
            }
            else {
                $attr = $gpxDoc.CreateAttribute("muitiRoute")
                $attr.Value = "1"
                $trkpt.Attributes.Append($attr) | Out-Null
            }
        }

        # ③ 保存
        $gpxDoc.Save($InputGpxPath)
        Write-Host "✅ trkptタグに muitiRoute 属性を付与して保存しました: $OutputGpxPath" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
    }
}