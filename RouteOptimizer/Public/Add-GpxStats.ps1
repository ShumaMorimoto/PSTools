function Add-GpxStats {
    param (
        [Parameter(Mandatory)]
        [xml]$GpxXml
    )

    $trkpts = $GpxXml.gpx.trk.trkseg.trkpt
    if (-not $trkpts -or $trkpts.Count -lt 2) {
        Write-Warning "trkptが不足しています。統計情報は追加されません。"
        return $GpxXml
    }

    # 総距離を計算
    $totalDistance = 0.0
    for ($i = 0; $i -lt $trkpts.Count - 1; $i++) {
        $totalDistance += Get-Distance $trkpts[$i] $trkpts[$i + 1]
    }

    $pointCount = $trkpts.Count
    $trkNode = $GpxXml.gpx.trk

    # 既存の <extensions> を探すか新規作成
    $extNode = $trkNode.extensions
    if (-not $extNode) {
        $extNode = $GpxXml.CreateElement("extensions")
        $trkNode.AppendChild($extNode) | Out-Null
    }
    else {
        # 既存の <stats> ノードを削除（名前空間なし前提）
        $existingStats = $extNode.stats
        if ($existingStats) {
            $extNode.RemoveChild($existingStats) | Out-Null
        }
    }

    # <stats> ノードを追加
    $statsNode = $GpxXml.CreateElement("stats")

    $distNode = $GpxXml.CreateElement("totalDistanceKm")
    $distNode.InnerText = [string]::Format("{0:F2}", $totalDistance)
    $statsNode.AppendChild($distNode) | Out-Null

    $countNode = $GpxXml.CreateElement("pointCount")
    $countNode.InnerText = "$pointCount"
    $statsNode.AppendChild($countNode) | Out-Null

    $extNode.AppendChild($statsNode) | Out-Null

    return $GpxXml
}