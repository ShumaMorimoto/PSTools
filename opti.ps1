# Haversine距離計算関数
function Get-HaversineDistance {
    param (
        [double[]]$coord1,  # [lat, lon]
        [double[]]$coord2
    )
    $R = 6371.0  # 地球半径 (km)
    $lat1 = [math]::ToRadians($coord1[0])
    $lon1 = [math]::ToRadians($coord1[1])
    $lat2 = [math]::ToRadians($coord2[0])
    $lon2 = [math]::ToRadians($coord2[1])
    $dlat = $lat2 - $lat1
    $dlon = $lon2 - $lon1
    $a = [math]::Sin($dlat / 2) * [math]::Sin($dlat / 2) + [math]::Cos($lat1) * [math]::Cos($lat2) * [math]::Sin($dlon / 2) * [math]::Sin($dlon / 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

# 距離行列計算
function Get-DistanceMatrix {
    param (
        [double[][]]$points
    )
    $n = $points.Length
    $distMatrix = New-Object 'double[,]' $n, $n
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) {
            if ($i -eq $j) { $distMatrix[$i,$j] = 0 } else {
                $distMatrix[$i,$j] = Get-HaversineDistance $points[$i] $points[$j]
            }
        }
    }
    return $distMatrix
}

# シンプルk-meansクラスタリング (ランダム初期化、最大イテレーション100)
function Get-KMeansClusters {
    param (
        [double[][]]$points,
        [int]$numClusters
    )
    $n = $points.Length
    # ランダムにセントロイド初期化
    $centroids = @()
    $randomIndices = (0..($n-1) | Get-Random -Count $numClusters)
    foreach ($idx in $randomIndices) { $centroids += ,$points[$idx] }
    
    $clusters = New-Object int[] $n
    $maxIter = 100
    for ($iter = 0; $iter -lt $maxIter; $iter++) {
        # 割り当て
        for ($i = 0; $i -lt $n; $i++) {
            $minDist = [double]::MaxValue
            $bestCluster = 0
            for ($c = 0; $c -lt $numClusters; $c++) {
                $dist = Get-HaversineDistance $points[$i] $centroids[$c]
                if ($dist -lt $minDist) { $minDist = $dist; $bestCluster = $c }
            }
            $clusters[$i] = $bestCluster
        }
        # セントロイド更新
        $newCentroids = New-Object 'double[][]' $numClusters
        $counts = New-Object int[] $numClusters
        for ($c = 0; $c -lt $numClusters; $c++) {
            $newCentroids[$c] = @(0, 0)
        }
        for ($i = 0; $i -lt $n; $i++) {
            $c = $clusters[$i]
            $newCentroids[$c][0] += $points[$i][0]
            $newCentroids[$c][1] += $points[$i][1]
            $counts[$c]++
        }
        $changed = $false
        for ($c = 0; $c -lt $numClusters; $c++) {
            if ($counts[$c] -gt 0) {
                $newCentroids[$c][0] /= $counts[$c]
                $newCentroids[$c][1] /= $counts[$c]
                if ($newCentroids[$c][0] -ne $centroids[$c][0] -or $newCentroids[$c][1] -ne $centroids[$c][1]) { $changed = $true }
            }
        }
        $centroids = $newCentroids
        if (-not $changed) { break }
    }
    return $clusters, $centroids
}

# GAによるTSP最適化 (Ordered Crossover + Swap Mutation)
function Optimize-TSPWithGA {
    param (
        [double[,]]$distMatrix,
        [int]$popSize = 100,
        [int]$generations = 200,
        [double]$mutationRate = 0.05
    )
    $n = $distMatrix.GetLength(0)
    # 初期集団
    $population = @()
    for ($i = 0; $i -lt $popSize; $i++) {
        $route = 0..($n-1) | Get-Random -Shuffle
        $population += ,$route
    }
    
    function Get-Fitness {
        param ([int[]]$route)
        $dist = 0
        for ($i = 0; $i -lt ($n-1); $i++) { $dist += $distMatrix[$route[$i], $route[$i+1]] }
        $dist += $distMatrix[$route[$n-1], $route[0]]  # 循環
        return $dist
    }
    
    for ($gen = 0; $gen -lt $generations; $gen++) {
        # エリート選択 (上位半分)
        $population = $population | Sort-Object { Get-Fitness $_ } | Select-Object -First ($popSize / 2)
        $newPop = @()
        while ($newPop.Count -lt $popSize) {
            # 親選択 (上位1/4から)
            $parent1 = $population[(Get-Random -Maximum ($popSize / 4))]
            $parent2 = $population[(Get-Random -Maximum ($popSize / 4))]
            # Ordered Crossover
            $start, $end = (1..($n-2) | Get-Random -Count 2 | Sort-Object)
            $child = New-Object int[] $n
            for ($i = $start; $i -le $end; $i++) { $child[$i] = $parent1[$i] }
            $remaining = $parent2 | Where-Object { $_ -notin $child[$start..$end] }
            $remIdx = 0
            for ($i = 0; $i -lt $n; $i++) {
                if ($child[$i] -eq 0) { $child[$i] = $remaining[$remIdx]; $remIdx++ }
            }
            # Mutation
            if ((Get-Random -Maximum 1) -lt $mutationRate) {
                $swap1, $swap2 = 0..($n-1) | Get-Random -Count 2
                $temp = $child[$swap1]; $child[$swap1] = $child[$swap2]; $child[$swap2] = $temp
            }
            $newPop += ,$child
        }
        $population += $newPop
    }
    # ベストルート
    $bestRoute = $population | Sort-Object { Get-Fitness $_ } | Select-Object -First 1
    return $bestRoute, (Get-Fitness $bestRoute)
}

# メイン処理
# テスト用ランダムポイント生成 (実際はCSV読み込みに置き換え)
$numPoints = 50  # テスト用、最大1000
$points = @()
for ($i = 0; $i -lt $numPoints; $i++) {
    $lat = 35 + (Get-Random -Maximum 1.0)
    $lon = 139 + (Get-Random -Maximum 1.0)
    $points += ,@($lat, $lon)
}

# CSV読み込み例 (コメントアウト解除)
# $points = Import-Csv -Path "points.csv" | ForEach-Object { @([double]$_.lat, [double]$_.lon) }

$distMatrix = Get-DistanceMatrix $points

# クラスタリング (拠点数/10のクラスタ数)
$numClusters = [math]::Max(1, [math]::Floor($numPoints / 10))
$clusters, $centroids = Get-KMeansClusters $points $numClusters
Write-Output "クラスタ数: $numClusters"

# 各クラスタ内TSP解決
$clusterRoutes = @{}
$clusterIds = 0..($numClusters-1)
foreach ($cid in $clusterIds) {
    $idx = @()
    for ($i = 0; $i -lt $numPoints; $i++) { if ($clusters[$i] -eq $cid) { $idx += $i } }
    if ($idx.Length -lt 2) { $clusterRoutes[$cid] = $idx; continue }
    $clusterDist = New-Object 'double[,]' $idx.Length, $idx.Length
    for ($i = 0; $i -lt $idx.Length; $i++) {
        for ($j = 0; $j -lt $idx.Length; $j++) {
            $clusterDist[$i,$j] = $distMatrix[$idx[$i], $idx[$j]]
        }
    }
    $route, $dist = Optimize-TSPWithGA $clusterDist
    $globalRoute = @()
    foreach ($r in $route) { $globalRoute += $idx[$r] }
    $clusterRoutes[$cid] = $globalRoute
}

# クラスタ間TSP (セントロイドで)
$centroidDist = Get-DistanceMatrix $centroids
$clusterOrder, $clusterDistTotal = Optimize-TSPWithGA $centroidDist

# フルルート結合
$fullRoute = @()
foreach ($ord in $clusterOrder) {
    $fullRoute += $clusterRoutes[$ord]
}
$fullRoute += $fullRoute[0]  # 循環閉じる

# 総距離計算
$totalDist = 0
for ($i = 0; $i -lt ($fullRoute.Length - 1); $i++) {
    $totalDist += $distMatrix[$fullRoute[$i], $fullRoute[$i+1]]
}

Write-Output "最適ルート: $($fullRoute -join ', ')"
Write-Output "総距離: $totalDist km"