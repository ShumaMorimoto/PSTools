function Crossover($parent1, $parent2) {
    $size = $parent1.Count
    $child = @(for ($i = 0; $i -lt $size; $i++) { $null })

    $start = Get-Random -Minimum 0 -Maximum $size
    $end = Get-Random -Minimum $start -Maximum $size

    # 親1の区間をコピー
    for ($i = $start; $i -lt $end; $i++) {
        $child[$i] = $parent1[$i]
    }

    # 親2の順序で残りを埋める
    foreach ($pt in $parent2) {
        if (-not ($child | Where-Object { IsSamePoint $_ $pt })) {
            for ($i = 0; $i -lt $size; $i++) {
                if (-not $child[$i]) {
                    $child[$i] = $pt
                    break
                }
            }
        }
    }
    return $child
}
