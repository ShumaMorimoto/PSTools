function Add-GpxStats {
    param (
        [Parameter(Mandatory)]
        [xml]$GpxXml
    )

    function Get-DistanceKm {
        param (
            [double]$lat1, [double]$lon1,
            [double]$lat2, [double]$lon2
        )
        $R = 6371
        $dLat = [math]::PI / 180 * ($lat2 - $lat1)
        $dLon = [math]::PI / 180 * ($lon2 - $lon1)
        $a = [math]::Pow([math]::Sin($dLat / 2), 2) +
             [math]::Cos([math]::PI / 180 * $lat1) *
             [math]::Cos([math]::PI / 180 * $lat2) *
             [math]::Pow([math]::Sin($dLon / 2), 2)
        $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
        return $R * $c
    }

    $trkpts = $GpxXml.gpx.trk.trkseg.trkpt
    if (-not $trkpts -or $trkpts.Count -lt 2) {
        Write-Warning "trkptが不足しています。統計情報は追加されません。"
        return $GpxXml
    }

    # 総距離を計算
    $totalDistance = 0.0
    for ($i = 0; $i -lt $trkpts.Count - 1; $i++) {
        $totalDistance += Get-DistanceKm $trkpts[$i].lat $trkpts[$i].lon $trkpts[$i + 1].lat $trkpts[$i + 1].lon
    }

    $pointCount = $trkpts.Count
    $trkNode = $GpxXml.gpx.trk

    # 既存の <extensions> を探すか新規作成
    $extNode = $trkNode.extensions
    if (-not $extNode) {
        $extNode = $GpxXml.CreateElement("extensions")
        $trkNode.AppendChild($extNode) | Out-Null
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