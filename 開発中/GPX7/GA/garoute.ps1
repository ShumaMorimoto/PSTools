using module D:\tool\Repository\PSTools\GPXTools

$towns = [GPXService]::FromCityTowns("横須賀市")
$places = $towns.GetTrkpts() | ForEach-Object {
    [ValueTuple[double, double]]::new($_.lat, $_.lon)
}


# 1. グローバル距離行列（C#）
$GlobalMatrix = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($places)

# 2. クラスタリング（PowerShell）
$Clusters = Cluster-Mesh $towns.GetTrkpts()  
$ClusterData = [System.Collections.ArrayList]::new()
$Clusters | ForEach-Object {[void]$ClusterData.Add([PSCustomObject]@{BestRouteGlobal=[];Nodes= $_})}

# 3. クラスタ内 TSP（C#）
foreach ($cluster in $ClusterData) {
    $cluster.BestRouteGlobal =  [TspSolverLib.OrToolsTsp]::SolveSubset($GlobalMatrix, $cluster.Nodes, 0)
}

# 4. クラスタ間距離行列（C#）
$ClusterMatrix =
[TspSolverLib.ClusterMatrixBuilder]::NewClusterDistanceMatrix(
    $ClusterData,
    $GlobalMatrix
)

# 5. クラスタ順序 TSP（C#）
$ClusterOrder =
[TspSolverLib.OrToolsTsp]::SolveFull($ClusterMatrix, 0)

# 6. 全体ルート合成
$FinalRoute = @()
foreach ($ci in $ClusterOrder) {
    $FinalRoute += $ClusterData[$ci].BestRouteGlobal
}

# 7. 区間最適化（C#）
$FinalRoute =
[TspSolverLib.OrToolsTsp]::SolveSegment(
    $GlobalMatrix,
    $FinalRoute,
    100,
    200
)