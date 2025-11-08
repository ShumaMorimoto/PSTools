
function Optimize-AreaRoute {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Places,
        [double]$DistanceKm = 2.0,
        [int]$PointLimit = 30,
        [int]$PopulationSize = 50,
        [int]$Generations = 100
    )

    # ① グリッドクラスタリング
    $clusters = Group-Places $Places -MaxDistanceKm $DistanceKm -MaxGroupSize $PointLimit

    # ② クラスタ重心算出
    $centroids = foreach ($cluster in $clusters) {
        $latAvg = ($cluster | ForEach-Object { [double]$_.lat } | Measure-Object -Average).Average
        $lonAvg = ($cluster | ForEach-Object { [double]$_.lon } | Measure-Object -Average).Average
        [PSCustomObject]@{
            Lat    = $latAvg
            Lon    = $lonAvg
            Points = $cluster
        }
    }

    # ③ クラスタ順序決定（Nearest Neighbor）
    $ordered = Optimize-Route $centroids 

    # ④ クラスタ内ルート最適化（ベース関数使用）
    $finalRoute = @($ordered[0].Points[0])

    for ($i = 0; $i -lt $ordered.Count; $i++) {
        $cluster = $ordered[$i]
        $start = $finalRoute[-1]
        $optimized = Optimize-Route -Places $cluster.Points -StartLocation $start -RouteMode "Open" `
            -PopulationSize 10 -Generations 50
        $finalRoute += $optimized
    }

    return $finalRoute
}