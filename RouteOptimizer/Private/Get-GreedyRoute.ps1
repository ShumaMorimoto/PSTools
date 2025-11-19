function Get-GreedyRoute {
    param (
        [array]$Points,
        [object]$StartLocation
    )

    $remaining = $Points.Clone()
    $route = @()
    $current = $StartLocation

    while ($remaining.Count -gt 0) {
        $next = $remaining | Sort-Object {
            Get-Distance $current $_
        } | Select-Object -First 1

        $route += $next
        $remaining = $remaining | Where-Object { $_ -ne $next }
        $current = $next
    }

    return $route
}

