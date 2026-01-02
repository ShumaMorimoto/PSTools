function New-NextGeneration {
    param(
        [array]$Population,
        [double[, ]]$DistanceMatrix,
        [double]$MutationRate = 0.3,
        [double]$EliteReserveRate = 0.05,
        [double]$GreedyMutationRate = 0.5
    )

    # ★ 拠点が 1 個なら GA は無意味 → スキップ
    if ($Population.Count -eq 0 -or $Population[0].Count -le 1) {
        return $Population
    }

    $popSize = $Population.Count

    # 1. 評価してソート
    $sortedCurrent = $Population | Sort-Object { Get-RouteDistance $_ $DistanceMatrix }

    # 2. エリート数
    $eliteCount = [math]::Floor($popSize * $EliteReserveRate)
    if ($eliteCount -lt 1) { $eliteCount = 1 }

    # 3. エリートコピー
    $next = @()
    $elites = $sortedCurrent[0..($eliteCount - 1)]
    foreach ($e in $elites) {
        $next += , ($e.Clone())
    }

    # 3.5 エリート改善（部分 Greedy）
    for ($idx = 1; $idx -lt $eliteCount; $idx++) {
        $route = $next[$idx]

        ($i, $j) = Get-Random -Minimum 0 -Maximum $route.Count

        if ($i -lt $j) {
            $next[$idx] = Get-GreedyRoute `
                -DistanceMatrix $DistanceMatrix `
                -Route $route `
                -StartPos $i `
                -EndPos $j
        }
    }

    # 4. 残りを生成
    while ($next.Count -lt $popSize) {
        # 親選択
        $parentA = Select-Tournament $Population $DistanceMatrix
        $parentB = Select-Tournament $Population $DistanceMatrix

        # 交叉
        $child = Invoke-CrossoverOX $parentA $parentB

        # Swap Mutation
        if ((Get-Random) -lt $MutationRate) {
            $child = Invoke-MutationSwap $child
        }

        # Greedy Mutation（局所改善）
        if ((Get-Random) -lt $GreedyMutationRate) {
            ($i, $j) = Get-Random -Minimum 0 -Maximum $child.Count 
            if ($i -lt $j) {
                $child = Get-GreedyRoute `
                    -DistanceMatrix $DistanceMatrix `
                    -Route $child `
                    -StartPos $i `
                    -EndPos $j
            }
        }
        $next += , $child
    }
    # 5. 次世代をソートして返す
    return ($next | Sort-Object { Get-RouteDistance $_ $DistanceMatrix })
}
