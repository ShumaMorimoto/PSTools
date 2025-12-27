function Select-Tournament {
    param(
        [array]$Population,
        [double[, ]]$Dist,
        [int]$K = 3
    )

    $candidates = 1..$K | ForEach-Object {
        Get-Random -InputObject $Population
    }
    return ($candidates | Sort-Object { Get-RouteDistance $_ $Dist })[0]
}
