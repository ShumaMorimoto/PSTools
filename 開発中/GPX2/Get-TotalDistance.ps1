function Get-TotalDistance {
    param (
        [array]$Route,
        [object]$StartLocation,
        [string]$RouteMode = "Open"
    )

    $total = 0
    if ($RouteMode -eq "Open") {
        $total += Get-Distance $StartLocation $Route[0]
        for ($i = 0; $i -lt $Route.Count - 1; $i++) {
            $total += Get-Distance $Route[$i] $Route[$i + 1]
        }
    }
    elseif ($RouteMode -eq "Circle") {
        $total += Get-Distance $StartLocation $Route[0]
        for ($i = 0; $i -lt $Route.Count - 1; $i++) {
            $total += Get-Distance $Route[$i] $Route[$i + 1]
        }
        $total += Get-Distance $Route[-1] $StartLocation
    }

    return $total
}
