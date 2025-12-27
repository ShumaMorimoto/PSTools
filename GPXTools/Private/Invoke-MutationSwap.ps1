function Invoke-MutationSwap {
    param([int[]]$Route)

    $new = $Route.Clone()
    ($i, $j) = Get-Random -Minimum 0 -Maximum $new.Count | Sort-Object

    $tmp = $new[$i]
    $new[$i] = $new[$j]
    $new[$j] = $tmp

    return $new
}
