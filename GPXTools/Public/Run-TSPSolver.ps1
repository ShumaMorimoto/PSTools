function Run-TSPSolver {
    param(
        [array]     $Places,
        [hashtable] $State
    )

    if ($Places.Count -gt 500) {

        Run-CTSPSolver $Places $State

    }
    else {

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
            [ValueTuple[double, double]]::new($_.lat, $_.lon)
        }

        # グローバル距離行列
        $GlobalDist = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($placesCsp)

        $initEnd = $sw.ElapsedMilliseconds
        $State.Performance.InitTime = $initEnd

        # --- Solve（TSPLib距離行列生成 + TSP） ---
        $State.Phase = "Solve"
        $solveStart = $sw.ElapsedMilliseconds

        $route = @(0)
        $route += [TspSolverLib.OrToolsTsp]::SolveFull($GlobalDist, 0)
        $dist = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $route,
            $GlobalDist
        )

        $solveEnd = $sw.ElapsedMilliseconds
        $State.Performance.SolveTime = $solveEnd - $solveStart

        # --- 結果 ---
        $State.Result = @{
            Route    = $route
            Distance = $dist
        }

        $State.Phase = "Finished"
        $State.Performance.TotalTime = $sw.ElapsedMilliseconds
    }

    return $State
}