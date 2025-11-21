function Split-Places {
    param (
        [Parameter(Mandatory)]
        [array]$Places,  # @{lat=..., lon=...} の配列

        [double]$DistanceKm = 0.0,
        [int]$PointLimit = 0
    )

    if (-not $Places -or $Places.Count -lt 2) {
        Write-Warning "Placesが不足しています。分割できません。"
        return @()
    }

    $routes = @()
    $currentRoute = @()
    $currentDistance = 0.0

    for ($i = 0; $i -lt $Places.Count - 1; $i++) {
        $pt1 = $Places[$i]
        $pt2 = $Places[$i + 1]

        $currentRoute += $pt1
        $dist = Get-Distance $pt1 $pt2
        $currentDistance += $dist

        $shouldSplit = ($DistanceKm -gt 0 -and $currentDistance -ge $DistanceKm) -or
                       ($PointLimit -gt 0 -and $currentRoute.Count -ge $PointLimit)

        if ($shouldSplit) {
            $currentRoute += $pt2
            $routes += ,$currentRoute
            $currentRoute = @()
            $currentDistance = 0.0
        }
    }

    if ($currentRoute.Count -gt 0) {
        $currentRoute += $Places[-1]
        $routes += ,$currentRoute
    }

    return $routes
}