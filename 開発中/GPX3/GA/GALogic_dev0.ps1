#==================================================================
# ダミー実装モジュール
#==================================================================

# 1) 距離行列系
function New-DistanceMatrix {
    param($places)
    $n = $places.Count
    $matrix = @()
    for ($i = 0; $i -lt $n; $i++) {
        $row = @()
        for ($j = 0; $j -lt $n; $j++) {
            $row += [math]::Abs($i - $j)    # |i-j| を距離とする
        }
        $matrix += , $row
    }
    return $matrix
}

function Get-SubMatrix {
    param($globalMatrix, $indices)
    $m = $indices.Count
    $sub = @()
    for ($i = 0; $i -lt $m; $i++) {
        $row = @()
        for ($j = 0; $j -lt $m; $j++) {
            $row += $globalMatrix[ $indices[$i] ][ $indices[$j] ]
        }
        $sub += , $row
    }
    return $sub
}

function Get-RouteDistance {
    param($route, $distMatrix)
    $total = 0
    for ($i = 0; $i -lt ($route.Count - 1); $i++) {
        $total += $distMatrix[ $route[$i] ][ $route[$i + 1] ]
    }
    return $total
}

# 2) クラスタリング系（ランダム分割）
function Cluster-Random {
    param(
        [int]$nClusters,
        [array]$places
    )
    $n = $places.Count
    $indices = 0..($n - 1) | Sort-Object { Get-Random }
    $clusters = @()
    $size = [math]::Ceiling($n / $nClusters)
    for ($i = 0; $i -lt $nClusters; $i++) {
        $start = $i * $size
        $end = [math]::Min(($i + 1) * $size - 1, $n - 1)
        if ($start -le $end) {
            $clusters += , ($indices[$start..$end])
        }
    }
    return $clusters
}

# 3) TSP‐GAモジュール（ダミー：そのまま0..m-1の順序を返す）
function Solve-TSPwithGA {
    param($distMatrix)
    $m = $distMatrix.Count
    $route = 0..($m - 1)
    $dist = Get-RouteDistance $route $distMatrix
    return @{ Route = $route; Dist = $dist }
}

# 4) クラスタ間ルーティング系
function Build-ClusterDistMatrixFromRoutes {
    param($globalMatrix, $clusterData)
    $k = $clusterData.Count
    $mat = @()
    for ($i = 0; $i -lt $k; $i++) {
        $row = @()
        # クラスタ i の出口ノード
        $exitNode = $clusterData[$i].Route[-1]
        for ($j = 0; $j -lt $k; $j++) {
            # クラスタ j の入口ノード
            $entryNode = $clusterData[$j].Route[0]
            $row += $globalMatrix[$exitNode][$entryNode]
        }
        $mat += , $row
    }
    return $mat
}

function ConnectClustersByOrder {
    param($clusterData, $clusterOrder, $globalMatrix)
    $final = @()
    foreach ($ci in $clusterOrder) {
        # そのまま配列をくっつける
        $final += $clusterData[$ci].Route
    }
    return $final
}


#==================================================================
# メインフロー（検証用）
#==================================================================
# サンプル地点（座標は使っていませんが、要素数だけ揃えれば OK）
$Places = @(
    @{ Name = "A" }, @{ Name = "B" }, @{ Name = "C" },
    @{ Name = "D" }, @{ Name = "E" }, @{ Name = "F" }
)

# Step1: 全体距離行列
$DistGlobal = New-DistanceMatrix $Places

# Step2: 仮クラスタ分割
# ※ クラスタ数を大きくすると “1拠点クラスタ” が発生します
$Clusters = Cluster-Random -nClusters 4 -places $Places

Write-Host "=== Clusters (global indices) ==="
for ($i = 0; $i -lt $Clusters.Count; $i++) {
    $ci = $Clusters[$i]
    Write-Host " Cluster $i : [ $($ci -join ',') ]"
}

# Step3: サブマトリクス生成 & データ構造作成
$ClusterData = @()
foreach ($inds in $Clusters) {
    $ClusterData += @{
        Indices   = $inds
        SubMatrix = Get-SubMatrix $DistGlobal $inds
        Route     = @()
        Dist      = 0
    }
}

# 世代ループ（3世代だけ回す）
$MaxGen = 3
for ($gen = 1; $gen -le $MaxGen; $gen++) {
    Write-Host "`n=== Generation $gen ==="

    # Step4: 各クラスタ内最適化
    for ($i = 0; $i -lt $ClusterData.Count; $i++) {
        $cd = $ClusterData[$i]
        $sol = Solve-TSPwithGA $cd.SubMatrix

        # ローカル(0..m-1)→グローバルインデックスに変換
        $cd.Route = $sol.Route | ForEach-Object { $cd.Indices[$_] }
        $cd.Dist = $sol.Dist

        # ログ出力（インデックス配列も-joinで文字列化）
        Write-Host (
            " Cluster $i : " +
            "Indices = [ $($cd.Indices -join ',') ], " +
            "Route = [ $($cd.Route   -join ',') ], " +
            "Dist = $($cd.Dist)"
        )
    }

    # Step5: クラスタ間距離行列
    $clusterDist = Build-ClusterDistMatrixFromRoutes $DistGlobal $ClusterData
    Write-Host " Cluster-Distance-Matrix:"
    for ($i = 0; $i -lt $clusterDist.Count; $i++) {
        Write-Host ("  [" + ($clusterDist[$i] -join ' ') + "]")
    }

    # Step6: クラスタ間最適化
    $orderSol = Solve-TSPwithGA $clusterDist
    $clusterOrder = $orderSol.Route
    Write-Host " ClusterOrder = [ $($clusterOrder -join ',') ]"

    # Step7: 全体ルート連結 & 全体距離
    $finalRoute = ConnectClustersByOrder $ClusterData $clusterOrder $DistGlobal
    $finalDist = Get-RouteDistance    $finalRoute   $DistGlobal
    Write-Host " FinalRoute = [ $($finalRoute -join ',') ]  FinalDist = $finalDist"
}

Write-Host "`n=== Test End ==="
