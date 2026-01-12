function Get-GreedyRoute {
    param (
        [array]$Points,
        [object]$StartLocation = $null
    )

    if ($StartLocation) {
        # 通常モード: 指定された始点からGreedyRouteを構築
        $remaining = $Points.Clone()
        $route = @()
        $current = $StartLocation

        while ($remaining.Count -gt 0) {
            $next = $remaining |
            ForEach-Object {
                [pscustomobject]@{
                    Point    = $_
                    Distance = Get-Distance $current $_
                }
            } | Sort-Object Distance | Select-Object -First 1

            $route += $next.Point
            $remaining = $remaining | Where-Object { $_ -ne $next.Point }
            $current = $next.Point
        }

        return $route
    }
    else {
        # 始点未指定 → 北端・南端・西端・東端の4点を候補にする
        $north = ($Points | Sort-Object { $_.lat } -Descending | Select-Object -First 1)
        $south = ($Points | Sort-Object { $_.lat } | Select-Object -First 1)
        $east = ($Points | Sort-Object { $_.lon } -Descending | Select-Object -First 1)
        $west = ($Points | Sort-Object { $_.lon } | Select-Object -First 1)

        $candidates = @($north, $south, $east, $west)

        $bestRoute = $null
        $bestDist = [double]::PositiveInfinity

        foreach ($start in $candidates) {
            $remaining = $Points.Clone() | Where-Object { $_ -ne $start }
            $route = @($start)
            $current = $start

            while ($remaining.Count -gt 0) {
                $next = $remaining |
                ForEach-Object {
                    [pscustomobject]@{
                        Point    = $_
                        Distance = Get-Distance $current $_
                    }
                } | Sort-Object Distance | Select-Object -First 1

                $route += $next.Point
                $remaining = $remaining | Where-Object { $_ -ne $next.Point }
                $current = $next.Point
            }

            $dist = Get-TotalDistance $route -StartLocation $null -RouteMode "Free"
            if ($dist -lt $bestDist) {
                $bestDist = $dist
                $bestRoute = $route
            }
        }

        return $bestRoute
    }
}
