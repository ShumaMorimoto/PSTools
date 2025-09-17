function Get-TotalDistance($route) {
    $sum = 0
    for ($i = 0; $i -lt $route.Count - 1; $i++) {
        $sum += Get-Distance $route[$i] $route[$i + 1]
    }
    $sum += Get-Distance $route[-1] $route[0]
    return $sum
}
