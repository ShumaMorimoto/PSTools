using module D:\tool\Repository\PSTools\GPXTools

$towns = [GPXService]::FromCityTowns("横須賀市")




$places = $towns.GetTrkpts() | ForEach-Object {
    [ValueTuple[double, double]]::new($_.lat, $_.lon)
}

$GlobalDist = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($places)

$Clusters = Cluster-Mesh  ($towns.GetTrkpts())
$numClusters = $Clusters.Count

$order = (0..($numClusters - 1)) | Sort-Object { Get-Random }
$clusterRoutes = @{}
foreach ($cid in 0..($numClusters - 1)) {
    $nodes = $Clusters[$cid]
    $clusterRoutes[$cid] = $nodes | Sort-Object { Get-Random }
}

$globalRoute = @()

# ============================
# Step 2
# ============================
$routes = @{}
foreach ($cid in $order) {
    $nodes = $Clusters[$cid]
    $routes[$cid] = [TspSolverLib.OrToolsTsp]::SolveSubset(
        $GlobalDist,
        $nodes,
        $null
    )
}

$globalRoute = @()
foreach ($cid in $order) { $globalRoute += $routes[$cid] }
$dist2 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
    $globalRoute,
    $GlobalDist
)

# ============================
# Step 3
# ============================
$bestRoutesArray = @()
for ($cid = 0; $cid -lt $numClusters; $cid++) {
    $bestRoutesArray += , ([int[]]$routes[$cid])
}

$clusterDist = [TspSolverLib.ClusterMatrixBuilder]::NewClusterDistanceMatrix(
    $bestRoutesArray,
    $GlobalDist
)
[int[]]$clusterIds = 0..($numClusters - 1)

$globalRoute = @()
$order = [TspSolverLib.OrToolsTsp]::SolveSubset(
    $clusterDist,
    $clusterIds,
    $null
)

foreach ($cid in $order) { $globalRoute += $routes[$cid] }
$dist3 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
    $globalRoute,
    $GlobalDist
)

# ============================
# Step 4
# ============================


$routes4 = @{}
$prevEnd = $null

foreach ($cid in $order) {
    $nodes = $Clusters[$cid]
    $startNode = if ($prevEnd -eq $null) { $null } else { $prevEnd }

    $route4 = [TspSolverLib.OrToolsTsp]::SolveSubset(
        $GlobalDist,
        $nodes,
        $startNode
    )
    $routes4[$cid] = $route4
    if ($route4.Count -gt 0) { $prevEnd = $route4[-1] }
}

$globalRoute = @()
foreach ($cid in $order) { $globalRoute4 += $routes4[$cid] }

$dist4 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
    $globalRoute4,
    $State.GlobalDist
)


# ★ Order1 の出力は削除
Write-Host ("[Pipeline] Dist1={0}  Dist2={1}  Dist3={2}  Dist4={3}" -f `
        $dist1, $dist2, $dist3, $dist4)
            
