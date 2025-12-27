function Get-RouteDistance {
    param([int[]]$route, [double[, ]]$Dist)
    if ($route.Count -le 1) { return 0.0 }
    $s = 0.0
    for ($i = 0; $i -lt $route.Count - 1; $i++) { $s += $Dist[$route[$i], $route[$i + 1]] }
    return $s
}
