function New-InitialPopulation {
    param(
        [int]$PopSize,
        [double[, ]]$DistMatrix,   # この行列のサイズ(N)に合わせて 0..N-1 のルートを作る
        [double]$GreedyRatio = 0.5
    )

    $n = $DistMatrix.GetLength(0)
    $population = @()
    $baseNodes = 0..($n - 1)

    # Greedyで生成する個体数
    $greedyCount = [math]::Floor($PopSize * $GreedyRatio)

    # 1. Greedy パート
    for ($i = 0; $i -lt $greedyCount; $i++) {
        # 開始点をランダムに変える (0 ～ n-1)
        $start = Get-Random -Maximum $n
        
        # Routeを指定しなければ、自動的に 0..n-1 に対してGreedyを行う
        $route = Get-GreedyRoute -DistanceMatrix $DistMatrix -FixedStartNodeIndex $start
       
        $population += , $route
    }

    # 2. ランダム パート
    for ($i = $greedyCount; $i -lt $PopSize; $i++) {
        $route = $baseNodes | Sort-Object { Get-Random }
        $population += , $route
    }
    return $population
}
