using module D:\tool\Repository\PSTools\GPXTools

function Invoke-ClusterPipeline {
    param(
        [int[]]     $Order,      # クラスタ順序
        [array]     $Clusters,   # クラスタ（ここに直接ルートを上書き）
        [array]     $GlobalDist  # グローバル距離行列
    )

    # -------------------------
    # Step1: クラスタ内TSP（入口制約なし）
    # -------------------------
    $Order | ForEach-Object {
        $cid = $_
        $Clusters[$cid] = [TspSolverLib.OrToolsTsp]::SolveSubset(
            $GlobalDist,
            $Clusters[$cid],
            $null
        )
    }

    # -------------------------
    # Step2: クラスタ間TSP（Order最適化）
    # -------------------------
    $clusterDist = [TspSolverLib.ClusterMatrixBuilder]::NewClusterDistanceMatrix(
        $Clusters,      # ← Clusters をそのまま渡す（int[][]）
        $GlobalDist
    )

    $Order = [TspSolverLib.OrToolsTsp]::SolveSubset(
        $clusterDist,
        (0..($Clusters.Count - 1)),
        $null
    )

    # -------------------------
    # Step3: 入口制約付きクラスタ内TSP（Clusters を上書き）
    # -------------------------
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
    $globalRoute = foreach ($cid in $Order) { $Clusters[$cid] }
    $dist = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
        $globalRoute, $GlobalDist
    )

    return [pscustomobject]@{
        Order       = $Order
        Clusters    = $Clusters      # ← 最新のルート集合
        GlobalRoute = $globalRoute
        Distance    = $dist
    }
}

$towns = [GPXService]::FromCityTowns("横須賀市")


$state = @{}
$places = $towns.GetTrkpts() | ForEach-Object {
    [ValueTuple[double, double]]::new($_.lat, $_.lon)
}

$state.GlobalDist = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($places)
# クラスタ化
$state.Clusters = [TspSolverLib.Clustering]::MeshCluster($places)
$state.order = 0..($state.Clusters.count - 1)

$state = Invoke-ClusterPipeline $state.order $state.Clusters $state.GlobalDist

$state.Distance
