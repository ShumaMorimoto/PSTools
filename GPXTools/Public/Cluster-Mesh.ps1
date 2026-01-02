function Cluster-Mesh {
    param(
        [array]     $Places,
        [hashtable] $State
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    if (-not $State.ContainsKey('Performance')) {
        $State.Performance = @{
            InitTime  = 0
            SolveTime = 0
            TotalTime = 0
        }
    }

    $State.Phase = "Init"

    # places を C# 用に変換
    $placesCsp = $Places | ForEach-Object {
        [ValueTuple[double,double]]::new($_.lat, $_.lon)
    }

    $initEnd = $sw.ElapsedMilliseconds
    $State.Performance.InitTime = $initEnd

    # --- Solve（TSPLib距離行列生成 + TSP） ---
    $State.Phase = "Solve"
    $solveStart = $sw.ElapsedMilliseconds

    $Clusters = [TspSolverLib.Clustering]::MeshCluster($placesCsp)

    $solveEnd = $sw.ElapsedMilliseconds
    $State.Performance.SolveTime = $solveEnd - $solveStart

    # --- 結果 ---
    $State.Result = @{
        Clusters       = $Clusters
    }

    $State.Phase = "Finished"
    $State.Performance.TotalTime = $sw.ElapsedMilliseconds

    return $State
}