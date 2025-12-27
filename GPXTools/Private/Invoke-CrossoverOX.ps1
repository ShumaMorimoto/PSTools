function Invoke-CrossoverOX {
    param(
        [int[]]$A,
        [int[]]$B
    )

    $size = $A.Count
    $child = @(foreach ($i in 1..$size) { $null })

    # ★ 修馬さん指定のランダム区間
    ($i, $j) = Get-Random -Minimum 0 -Maximum $size | Sort-Object

    # A の区間をコピー
    for ($k = $i; $k -le $j; $k++) {
        $child[$k] = $A[$k]
    }

    # B の順序で残りを埋める
    $pos = ($j + 1) % $size
    foreach ($city in $B) {
        if ($child -notcontains $city) {
            $child[$pos] = $city
            $pos = ($pos + 1) % $size
        }
    }

    return $child
}
