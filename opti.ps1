function Get-HaversineDistance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Pt1,
        [Parameter(Mandatory)][object]$Pt2,
        [string]$LatProp = 'lat',
        [string]$LonProp = 'lon'
    )

    $R = 6371.0
    $lat1 = [double]($Pt1.PSObject.Properties[$LatProp].Value) * [math]::PI / 180.0
    $lon1 = [double]($Pt1.PSObject.Properties[$LonProp].Value) * [math]::PI / 180.0
    $lat2 = [double]($Pt2.PSObject.Properties[$LatProp].Value) * [math]::PI / 180.0
    $lon2 = [double]($Pt2.PSObject.Properties[$LonProp].Value) * [math]::PI / 180.0

    $dlat = $lat2 - $lat1
    $dlon = $lon2 - $lon1

    $a = [math]::Pow([math]::Sin($dlat / 2), 2) +
    [math]::Cos($lat1) * [math]::Cos($lat2) *
    [math]::Pow([math]::Sin($dlon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

function Get-DistanceMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Points,
        [string]$LatProp = 'lat',
        [string]$LonProp = 'lon'
    )

    $n = $Points.Count
    $distMatrix = [double[, ]]::new($n, $n)

    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) {
            if ($i -eq $j) {
                $distMatrix[$i, $j] = 0.0
            }
            else {
                $distMatrix[$i, $j] = Get-HaversineDistance -Pt1 $Points[$i] -Pt2 $Points[$j] -LatProp $LatProp -LonProp $LonProp
            }
        }
    }
    return , $distMatrix
}

function Get-KMeansClusters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Points,
        [int]$numClusters,
        [int]$maxIter = 100,
        [string]$LatProp = 'lat',
        [string]$LonProp = 'lon'
    )

    $n = $Points.Count
    if ($numClusters -gt $n) { $numClusters = $n }

    # 初期セントロイド
    $centroids = @()
    $randomIndices = (0..($n - 1) | Get-Random -Count $numClusters)
    foreach ($idx in $randomIndices) {
        $centroids += , [pscustomobject]@{
            lat = [double]$Points[$idx].PSObject.Properties[$LatProp].Value
            lon = [double]$Points[$idx].PSObject.Properties[$LonProp].Value
        }
    }

    $clusters = New-Object int[] $n

    for ($iter = 0; $iter -lt $maxIter; $iter++) {
        $changedAssign = $false
        for ($i = 0; $i -lt $n; $i++) {
            $minDist = [double]::MaxValue
            $best = 0
            for ($c = 0; $c -lt $numClusters; $c++) {
                $d = Get-HaversineDistance -Pt1 $Points[$i] -Pt2 $centroids[$c] -LatProp $LatProp -LonProp $LonProp
                if ($d -lt $minDist) { $minDist = $d; $best = $c }
            }
            if ($clusters[$i] -ne $best) { $changedAssign = $true }
            $clusters[$i] = $best
        }

        # セントロイド更新
        $sums = @(); $counts = @()
        for ($c = 0; $c -lt $numClusters; $c++) {
            $sums += , @([double]0.0, [double]0.0)
            $counts += 0
        }
        for ($i = 0; $i -lt $n; $i++) {
            $cid = $clusters[$i]
            $sums[$cid][0] += [double]$Points[$i].PSObject.Properties[$LatProp].Value
            $sums[$cid][1] += [double]$Points[$i].PSObject.Properties[$LonProp].Value
            $counts[$cid]++
        }
        $changedCentroid = $false
        for ($c = 0; $c -lt $numClusters; $c++) {
            if ($counts[$c] -gt 0) {
                $newLat = $sums[$c][0] / $counts[$c]
                $newLon = $sums[$c][1] / $counts[$c]
                if ($newLat -ne $centroids[$c].lat -or $newLon -ne $centroids[$c].lon) {
                    $centroids[$c] = [pscustomobject]@{ lat = $newLat; lon = $newLon }
                    $changedCentroid = $true
                }
            }
        }
        if (-not $changedAssign -and -not $changedCentroid) { break }
    }
    return $clusters, $centroids
}

function Optimize-TSPWithGA {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][double[, ]]$distMatrix,
        [int]$popSize = 50,
        [int]$generations = 30,
        [double]$mutationRate = 0.05
    )

    $n = $distMatrix.GetLength(0)
    $population = @()
    for ($i = 0; $i -lt $popSize; $i++) {
        $route = 0..($n - 1) | Get-Random -Shuffle
        $population += , $route
    }

    function Get-Fitness {
        param([int[]]$route)
        $d = 0.0
        for ($k = 0; $k -lt ($n - 1); $k++) { $d += $distMatrix[$route[$k], $route[$k + 1]] }
        $d += $distMatrix[$route[$n - 1], $route[0]]
        return $d
    }

    for ($gen = 0; $gen -lt $generations; $gen++) {
        $population = $population | Sort-Object { Get-Fitness $_ } | Select-Object -First ([int]($popSize / 2))
        $newPop = @()
        while ($newPop.Count -lt $popSize) {
            $parent1 = $population[(Get-Random -Maximum $population.Count)]
            $parent2 = $population[(Get-Random -Maximum $population.Count)]
            $start, $end = (1..($n - 2) | Get-Random -Count 2 | Sort-Object)
            $child = New-Object int[] $n
            for ($i = $start; $i -le $end; $i++) { $child[$i] = $parent1[$i] }
            $occupied = @(); for ($i = $start; $i -le $end; $i++) { $occupied += $child[$i] }
            $remaining = $parent2 | Where-Object { $occupied -notcontains $_ }
            $remIdx = 0
            for ($i = 0; $i -lt $n; $i++) {
                if ($i -ge $start -and $i -le $end) { continue }
                $child[$i] = $remaining[$remIdx]; $remIdx++
            }
            if ((Get-Random -Minimum 0 -Maximum 1.0) -lt $mutationRate) {
                $swap = 0..($n - 1) | Get-Random -Count 2
                $t = $child[$swap[0]]; $child[$swap[0]] = $child[$swap[1]]; $child[$swap[1]] = $t
            }
            $newPop += , $child
        }
        $population += $newPop
    }
    $bestRoute = $population | Sort-Object { Get-Fitness $_ } | Select-Object -First 1
    return $bestRoute, (Get-Fitness $bestRoute)
}
# ---------------------------
# Part2（後半）— メイン処理（テスト用データ生成〜実行）
# ---------------------------

# テスト用：pscustomobject 配列を作成（必要に応じて CSV 読み込みに差し替えてください）
$numPoints = 500
$points = @()
for ($i = 0; $i -lt $numPoints; $i++) {
    $lat = 35 + (Get-Random -Minimum 0 -Maximum 1.0)
    $lon = 139 + (Get-Random -Minimum 0 -Maximum 1.0)
    $points += , [pscustomobject]@{ lat = [double]$lat; lon = [double]$lon }
}

# CSV 読み込み例（lat/lon カラムがある場合）
# $points = Import-Csv -Path "points.csv" | ForEach-Object {
#     [pscustomobject]@{ lat = [double]$_.lat; lon = [double]$_.lon }
# }

# 距離行列作成
$distMatrix = Get-DistanceMatrix -Points $points

# クラスタ数の自動設定（例: 点数/10）
$numClusters = [math]::Max(1, [math]::Floor($points.Count / 10))
$clusters, $centroids = Get-KMeansClusters -Points $points -numClusters $numClusters
Write-Output "クラスタ数: $numClusters"

# 各クラスタ内で TSP を解く
$clusterRoutes = @{}
for ($cid = 0; $cid -lt $numClusters; $cid++) {
    $idx = @()
    for ($i = 0; $i -lt $numPoints; $i++) { if ($clusters[$i] -eq $cid) { $idx += $i } }
    if ($idx.Length -lt 2) { $clusterRoutes[$cid] = $idx; continue }

    $m = $idx.Length
    $clusterDist = [double[, ]]::new($m, $m)
    for ($i = 0; $i -lt $m; $i++) {
        for ($j = 0; $j -lt $m; $j++) {
            $clusterDist[$i, $j] = $distMatrix[$idx[$i], $idx[$j]]
        }
    }

    $route, $dist = Optimize-TSPWithGA -distMatrix $clusterDist
    $globalRoute = @()
    foreach ($r in $route) { $globalRoute += $idx[$r] }
    $clusterRoutes[$cid] = $globalRoute
}

# クラスタ間の順序決定（セントロイド間 TSP）
$centroidDist = Get-DistanceMatrix -Points $centroids
$clusterOrder, $clusterDistTotal = Optimize-TSPWithGA -distMatrix $centroidDist

# 全ルートを結合（クラスタ順に各クラスタルートを連結）
$fullRoute = @()
foreach ($ord in $clusterOrder) {
    $fullRoute += $clusterRoutes[$ord]
}
if ($fullRoute.Count -gt 0) { $fullRoute += $fullRoute[0] }  # 出発点に戻る

# 総距離計算
$totalDist = 0.0
for ($i = 0; $i -lt ($fullRoute.Length - 1); $i++) {
    $totalDist += $distMatrix[$fullRoute[$i], $fullRoute[$i + 1]]
}

Write-Output "最適ルート: $($fullRoute -join ', ')"
Write-Output "総距離: $totalDist km"

# 注意:
# - CSV を使う場合は上の Import-Csv 部分を有効化してください。
# - パラメータ調整（numClusters / GA の popSize, generations, mutationRate）は運用に合わせて変更してください。
