function Get-GreedyRoute {
    param (
        [array]$Points,
        [object]$StartLocation
    )

    # 残りの候補をコピー
    $remaining = $Points.Clone()
    $route     = @()
    $current   = $StartLocation

    while ($remaining.Count -gt 0) {
        # 各候補に距離を付与してソート
        $next = $remaining |
            ForEach-Object {
                [pscustomobject]@{
                    Point    = $_
                    Distance = Get-Distance $current $_
                }
            } |
            Sort-Object Distance |
            Select-Object -First 1

        # 最短距離の点をルートに追加
        $route += $next.Point
        # 残りから削除
        $remaining = $remaining | Where-Object { $_ -ne $next.Point }
        # 現在位置を更新
        $current = $next.Point
    }

    return $route
}

