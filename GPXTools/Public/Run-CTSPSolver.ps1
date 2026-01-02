function Run-CTSPSolver {
    param(
        [array]     $Places,
        [hashtable] $State
    )

    # --- Stopwatch ---
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # --- Performance 初期化 ---
    if (-not $State.ContainsKey('Performance')) {
        $State.Performance = @{
            InitTime  = 0
            SolveTime = 0
            TotalTime = 0
        }
    }

    # -------------------------
    # Init Phase
    # -------------------------
    $State.Phase = "Init"

    # C# 用に変換
    $placesCsp = $Places | ForEach-Object {
        [ValueTuple[double,double]]::new($_.lat, $_.lon)
    }

    # グローバル距離行列
    $GlobalDist = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($placesCsp)

    # KMeans クラスタリング
    $Clusters = [TspSolverLib.Clustering]::KMeansCluster($placesCsp)

    # 初期 Order
    $Order = 0..($Clusters.Count - 1)

    # Init 終了時間
    $initEnd = $sw.ElapsedMilliseconds
    $State.Performance.InitTime = $initEnd

    # -------------------------
    # Solve Phase
    # -------------------------
    $State.Phase = "Solve"
    $solveStart = $sw.ElapsedMilliseconds

    # --- Step1: クラスタ内TSP（入口制約なし） ---
    $Order | ForEach-Object {
        $cid = $_
        $Clusters[$cid] = [TspSolverLib.OrToolsTsp]::SolveSubset(
            $GlobalDist,
            $Clusters[$cid],
            $null
        )
    }

    # --- Step2: クラスタ間TSP（Order最適化） ---
    $clusterDist = [TspSolverLib.ClusterMatrixBuilder]::NewClusterDistanceMatrix(
        $Clusters,
        $GlobalDist
    )

    $Order = [TspSolverLib.OrToolsTsp]::SolveSubset(
        $clusterDist,
        (0..($Clusters.Count - 1)),
        $null
    )

    # --- Step3: 入口制約付きクラスタ内TSP ---
    $prevEnd = $null
    $Order | ForEach-Object {
        $cid = $_
        $Clusters[$cid] = [TspSolverLib.OrToolsTsp]::SolveSubset(
            $GlobalDist,
            $Clusters[$cid],
            $prevEnd
        )
        if ($Clusters[$cid].Count -gt 0) {
            $prevEnd = $Clusters[$cid][-1]
        }
    }

    # --- GlobalRoute ---
    $route = foreach ($cid in $Order) { $Clusters[$cid] }
    $dist = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
        $route,
        $GlobalDist
    )

    # Solve 終了時間
    $solveEnd = $sw.ElapsedMilliseconds
    $State.Performance.SolveTime = $solveEnd - $solveStart

    # -------------------------
    # 結果格納
    # -------------------------
    $State.Result = @{
        Order       = $Order
        Clusters    = $Clusters
        Route       = $route
        Distance    = $dist
    }

    $State.Phase = "Finished"
    $State.Performance.TotalTime = $sw.ElapsedMilliseconds

    return $State
}