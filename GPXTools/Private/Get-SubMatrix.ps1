function Get-SubMatrix {
    param($globalDistanceMatrix, $indices)
    $m = $indices.Count; $sub = [double[, ]]::new($m, $m)
    for ($i = 0; $i -lt $m; $i++) { for ($j = 0; $j -lt $m; $j++) { $sub[$i, $j] = $globalDistanceMatrix[$indices[$i], $indices[$j]] } }
    return , $sub
}
