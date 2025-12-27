function New-DistanceMatrix {
    param([array]$Places)
    $n = $Places.Count
    $dist = [double[, ]]::new($n, $n)
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = $i; $j -lt $n; $j++) {
            if ($i -eq $j) { $dist[$i, $j] = [double]::PositiveInfinity } else {
                $d = Get-Distance $Places[$i] $Places[$j]
                $dist[$i, $j] = $d; $dist[$j, $i] = $d
            }
        }
    }
    return , $dist
}
