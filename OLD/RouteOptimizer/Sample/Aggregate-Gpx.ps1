using module RouteOptimizer

param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.aggregated.gpx')"
)

function Aggregate-Places {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Places
    )

    # keywordがある拠点のみ対象
    $placesWithKeyword = $Places | Where-Object {
        $_.extensions.keyword
    }

    # lat+lonでグループ化
    $aggregated = $placesWithKeyword | Group-Object {
        "$($_.lat),$($_.lon)"
    } | ForEach-Object {
        $group = $_.Group
        $first = $group[0]

        # countノードを追加（既存があれば更新）
        $extensionsNode = $first.extensions
        $countNode = $extensionsNode.SelectSingleNode("count")
        if (-not $countNode) {
            $countNode = $extensionsNode.OwnerDocument.CreateElement("count")
            $extensionsNode.AppendChild($countNode) | Out-Null
        }
        $countNode.InnerText = $_.Count

        # 集約結果として返す
        $first
    }

    return $aggregated
}

try {
    # ① GPX読み込み
    $gpxDoc = [GPXDocument]::Load($InputGpxPath)

    # ② 拠点取得
    $trkpts = $gpxDoc.GetTrkPts()

    # ③ 集約処理
    $aggregated = Aggregate-Places -Places $trkpts

    # ④ 再構築
    $gpxDoc.SetTrkPts($aggregated)

    # ⑤ 保存
    $gpxDoc.Save($OutputGpxPath)
    Write-Host "✅ 集約GPXファイルを保存しました: $OutputGpxPath" -ForegroundColor Green
}
catch {
    Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
}

