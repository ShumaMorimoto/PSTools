function Run-GASimulation {
    param(
        [array]     $Places,
        [hashtable] $State,
        [int]       $PopSizePerCluster = 50,
        [int]       $PopSizeClustersOrder = 50,
        [int]       $MaxGen = 1000,
        [int]       $NumClusters = 10
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $State.ContainsKey('Performance')) {
        $State.Performance = @{
            InitTime       = 0
            ClusterGATime  = 0
            MatrixCalcTime = 0
            OrderGATime    = 0
            EvalTime       = 0
            TotalLoopTime  = 0
        }
    }

    $State.Phase = "Init"


    # --- 1. Place が指定された場合は必ず再構築 ---
    if ($Places) {
        $State.Input = $Places
        $State.GlobalMatrix = New-DistanceMatrix $Places
    }
    else {
        # --- 2. Place が指定されていない場合は継続実行 ---
        # Matrix と Place の整合性チェック
        if (-not $State.GlobalMatrix -or $State.GlobalMatrix.Count -ne $State.Input.Count) {
            # --- 3. 整合性が取れない場合は再構築 ---
            $State.GlobalMatrix = New-DistanceMatrix $State.Input
        }
    }

    # --- 初期化 ---
    if (-not $State.ContainsKey('ClusterData')) {

        $State.Phase = "ClusterInit"
        $initStart = $sw.ElapsedMilliseconds

        $clusters = Cluster-Mesh -Places $State.Input
        $cd = @()

        for ($ci = 0; $ci -lt $clusters.Count; $ci++) {
            $inds = $clusters[$ci]
            $sub = Get-SubMatrix $State.GlobalMatrix $inds

            $pop = New-InitialPopulation -PopSize $PopSizePerCluster `
                -DistMatrix $sub `
                -GreedyRatio 0.5

            $sortedPop = $pop | Sort-Object { Get-RouteDistance $_ $sub }
            $bestLocal = $sortedPop[0]
            $bestGlobal = $bestLocal | ForEach-Object { $inds[$_] }

            $cd += , @{
                Indices         = $inds
                SubMatrix       = $sub
                Population      = $sortedPop
                BestRouteLocal  = $bestLocal
                BestRouteGlobal = $bestGlobal
                BestDist        = (Get-RouteDistance $bestLocal $sub)
            }
        }

        $State.ClusterData = $cd

        # --- クラスタ順序初期化 ---
        $clusterDistMatrix = New-ClusterDistanceMatrix -ClusterData $State.ClusterData -GlobalMatrix $State.GlobalMatrix

        $orderPop = New-InitialPopulation -PopSize $PopSizeClustersOrder `
            -DistMatrix $clusterDistMatrix `
            -GreedyRatio 0.5

        $sortedOrderPop = $orderPop | Sort-Object { Get-RouteDistance $_ $clusterDistMatrix }

        $State.ClusterOrderPopulation = $sortedOrderPop
        $State.BestClusterOrder = $sortedOrderPop[0]

        # --- 初期ルート構築 ---
        $fullRoute = @()
        foreach ($cIdx in $State.BestClusterOrder) {
            $fullRoute += $State.ClusterData[$cIdx].BestRouteGlobal
        }

        $initialDist = Get-RouteDistance $fullRoute $State.GlobalMatrix

        # ★ 外部公開用は Result に一本化
        $State.Result = @{
            Route    = $fullRoute
            Distance = $initialDist
        }

        $State.Generation = 0
        $State.UpdatedAt = (Get-Date).ToUniversalTime()

        $initEnd = $sw.ElapsedMilliseconds
        $State.Performance.InitTime = $initEnd - $initStart
    }

    # --- GA ループ ---
    while (-not $State.Stop) {

        $t_start = $sw.ElapsedMilliseconds

        # --- クラスタ内 GA ---
        $State.Phase = "ClusterGA"
        for ($ci = 0; $ci -lt $State.ClusterData.Count; $ci++) {
            $c = $State.ClusterData[$ci]

            if ($c.Indices.count -gt 1) {
                $c.Population = New-NextGeneration -Population $c.Population -DistanceMatrix $c.SubMatrix
            }

            $bestLocal = $c.Population[0]
            $c.BestRouteLocal = $bestLocal
            $c.BestRouteGlobal = $bestLocal | ForEach-Object { $c.Indices[$_] }
            $c.BestDist = Get-RouteDistance $c.BestRouteGlobal $State.GlobalMatrix
        }
        $t_clusterGA = $sw.ElapsedMilliseconds

        # --- クラスタ間距離行列 ---
        $State.Phase = "OrderGA"
        $clusterDistanceMatrix = New-ClusterDistanceMatrix $State.ClusterData $State.GlobalMatrix
        $t_matrix = $sw.ElapsedMilliseconds

        # --- クラスタ順序 GA ---
        $State.ClusterOrderPopulation = New-NextGeneration -Population $State.ClusterOrderPopulation -Dist $clusterDistanceMatrix
        $t_orderGA = $sw.ElapsedMilliseconds

        # --- 全体ルート評価 ---
        $State.Phase = "Evaluate"
        $bestOrder = $State.ClusterOrderPopulation[0]

        $finalRoute = @()
        foreach ($ci in $bestOrder) {
            $finalRoute += $State.ClusterData[$ci].BestRouteGlobal
        }

        $finalDistance = Get-RouteDistance $finalRoute $State.GlobalMatrix

        # --- State 更新 ---
        $State.Generation++
        $State.UpdatedAt = (Get-Date).ToUniversalTime()

        # ★ 外部公開用は Result に一本化
        $State.Result = @{
            Route    = $finalRoute
            Distance = $finalDistance
        }

        # --- パフォーマンス計測 ---
        $t_eval = $sw.ElapsedMilliseconds
        $State.Performance.ClusterGATime = $t_clusterGA - $t_start
        $State.Performance.MatrixCalcTime = $t_matrix - $t_clusterGA
        $State.Performance.OrderGATime = $t_orderGA - $t_matrix
        $State.Performance.EvalTime = $t_eval - $t_orderGA
        $State.Performance.TotalLoopTime = $t_eval - $t_start

        if ($State.Generation -ge $MaxGen) { break }
    }

    $State.Phase = "Finished"
    $sw.Stop()

    return $State
}