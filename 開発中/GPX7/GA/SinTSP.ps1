using module D:\tool\Repository\PSTools\GPXTools

function Measure-ClusterEvaluation {
    param(
        [array]       $Places,
        [hashtable]   $State,
        [scriptblock] $ClusterFunc,     # ★ 追加：クラスタ関数を外部注入
        [int]         $PopSizeOrder = 10,
        [int]         $MaxGen = 1000
    )

    Write-Host "=== Init Phase ==="

    $State.Phase = "Init"

    # 1. グローバル距離行列
    Write-Host "[Init] Building global distance matrix..."
    $State.GlobalDist = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($Places)

    # 2. クラスタ分割（外部注入）
    Write-Host "[Init] Clustering places..."
    $placesLatLon = $Places | ForEach-Object { @{ lat = $_.Item1; lon = $_.Item2 } }
    $State.Clusters = & $ClusterFunc $placesLatLon 
    $numClusters = $State.Clusters.Count
    Write-Host "[Init] Clusters: $numClusters"

    # 3. 初期集団
    Write-Host "[Init] Creating initial population..."
    $population = @()

    for ($i = 0; $i -lt $PopSizeOrder; $i++) {
        $order = (0..($numClusters - 1)) | Sort-Object { Get-Random }
        $clusterRoutes = @{}
        foreach ($cid in 0..($numClusters - 1)) {
            $nodes = $State.Clusters[$cid]
            $clusterRoutes[$cid] = $nodes | Sort-Object { Get-Random }
        }
        $population += [pscustomobject]@{
            Order         = $order
            ClusterRoutes = $clusterRoutes
        }
    }

    $State.OrderPopulation = $population

    # 4. フルTSP
    Write-Host "[Init] Running full TSP without clustering..."
    $swFull = [System.Diagnostics.Stopwatch]::StartNew()
 #   $fullRoute = [TspSolverLib.OrToolsTsp]::SolveFull($State.GlobalDist)
 #   $fullDist = [TspSolverLib.DistanceBuilder]::GetRouteDistance($fullRoute, $State.GlobalDist)
    $swFull.Stop()

    Write-Host "[FullTSP] Distance = $fullDist  Time=${($swFull.ElapsedMilliseconds)}ms"

    # --- Step1〜4 の時間集計 ---
    $time1 = 0
    $time2 = 0
    $time3 = 0
    $time4 = 0

    Write-Host "[Init] Measuring cluster/order TSP pipeline..."

    foreach ($ind in $State.OrderPopulation) {
        $dist4List = @()
        $order1 = $ind.Order
        $routes1 = $ind.ClusterRoutes

        # ============================
        # Step 1
        # ============================
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $globalRoute1 = @()
        foreach ($cid in $order1) { $globalRoute1 += $routes1[$cid] }

        $dist1 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $globalRoute1,
            $State.GlobalDist
        )

        $sw.Stop()
        $time1 += $sw.ElapsedMilliseconds

        # ============================
        # Step 2
        # ============================
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $routes2 = @{}
        foreach ($cid in $order1) {
            $nodes = $State.Clusters[$cid]
            $routes2[$cid] = [TspSolverLib.OrToolsTsp]::SolveSubset(
                $State.GlobalDist,
                $nodes,
                $null
            )
        }

        $globalRoute2 = @()
        foreach ($cid in $order1) { $globalRoute2 += $routes2[$cid] }

        $dist2 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $globalRoute2,
            $State.GlobalDist
        )

        $sw.Stop()
        $time2 += $sw.ElapsedMilliseconds

        # ============================
        # Step 3
        # ============================
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $bestRoutesArray = @()
        for ($cid = 0; $cid -lt $numClusters; $cid++) {
            $bestRoutesArray += , ([int[]]$routes2[$cid])
        }

        $clusterDist = [TspSolverLib.ClusterMatrixBuilder]::NewClusterDistanceMatrix(
            $bestRoutesArray,
            $State.GlobalDist
        )

        $clusterIds = 0..($numClusters - 1)

        $order3 = [TspSolverLib.OrToolsTsp]::SolveSubset(
            $clusterDist,
            $clusterIds,
            $null
        )

        $globalRoute3 = @()
        foreach ($cid in $order3) { $globalRoute3 += $routes2[$cid] }

        $dist3 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $globalRoute3,
            $State.GlobalDist
        )

        $sw.Stop()
        $time3 += $sw.ElapsedMilliseconds

        # ============================
        # Step 4
        # ============================
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $routes4 = @{}
        $prevEnd = $null

        foreach ($cid in $order3) {
            $nodes = $State.Clusters[$cid]
            $startNode = if ($prevEnd -eq $null) { $null } else { $prevEnd }

            $route4 = [TspSolverLib.OrToolsTsp]::SolveSubset(
                $State.GlobalDist,
                $nodes,
                $startNode
            )

            $routes4[$cid] = $route4
            if ($route4.Count -gt 0) { $prevEnd = $route4[-1] }
        }

        $globalRoute4 = @()
        foreach ($cid in $order3) { $globalRoute4 += $routes4[$cid] }

        $dist4 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $globalRoute4,
            $State.GlobalDist
        )
        $dist4List += $dist4

        $sw.Stop()
        $time4 += $sw.ElapsedMilliseconds

        # ★ Order1 の出力は削除
        Write-Host ("[Pipeline] Dist1={0}  Dist2={1}  Dist3={2}  Dist4={3}" -f `
                $dist1, $dist2, $dist3, $dist4)

            
    }

    # --- 平均時間 ---
    Write-Host "=== Average Time (ms) ==="
    Write-Host ("Step1: {0} ms" -f ($time1 / $State.OrderPopulation.Count))
    Write-Host ("Step2: {0} ms" -f ($time2 / $State.OrderPopulation.Count))
    Write-Host ("Step3: {0} ms" -f ($time3 / $State.OrderPopulation.Count))
    Write-Host ("Step4: {0} ms" -f ($time4 / $State.OrderPopulation.Count))
    Write-Host ("FullTSP: {0} ms" -f $swFull.ElapsedMilliseconds)

    # --- 平均時間 ---
    Write-Host "=== Average Time (ms) ==="
    $avg1 = $time1 / $State.OrderPopulation.Count
    $avg2 = $time2 / $State.OrderPopulation.Count
    $avg3 = $time3 / $State.OrderPopulation.Count
    $avg4 = $time4 / $State.OrderPopulation.Count

    Write-Host ("Step1: {0} ms" -f $avg1)
    Write-Host ("Step2: {0} ms" -f $avg2)
    Write-Host ("Step3: {0} ms" -f $avg3)
    Write-Host ("Step4: {0} ms" -f $avg4)
    Write-Host ("FullTSP: {0} ms" -f $swFull.ElapsedMilliseconds)

    # ============================
    # ★ 追加：クラスタTSP vs フルTSP の比較
    # ============================

    # クラスタTSPの代表距離（Step4 の平均）
    $clusterAvgDist = ($dist4List | Measure-Object -Average).Average

    # 改善率（クラスタTSP / フルTSP）
    $improveRate = $clusterAvgDist / $fullDist

    # クラスタTSPの平均処理時間（Step1〜4 の合計）
    $clusterAvgTime = $avg1 + $avg2 + $avg3 + $avg4

    Write-Host "=== Cluster vs Full TSP Summary ==="
    Write-Host ("FullTSP Distance     : {0}" -f $fullDist)
    Write-Host ("ClusterTSP Distance  : {0}" -f $clusterAvgDist)
    Write-Host ("Improve Rate         : {0:P2}" -f $improveRate)
    Write-Host ("FullTSP Time (ms)    : {0}" -f $swFull.ElapsedMilliseconds)
    Write-Host ("ClusterTSP Time (ms) : {0}" -f $clusterAvgTime)

    return $State
}

function Cluster-Mesh {
    param(
        [Parameter(Mandatory)]
        [array]$Places,

        [double]$MeshKm = 5.0,      # メッシュ幅（km）
        [int]$MaxGroupSize = 50     # クラスタ上限
    )

    # --- 度数換算（km → 緯度経度の度） ---
    function Get-MeshSteps {
        param([array]$Places, [double]$MeshKm)

        $latStep = $MeshKm / 111.0
        $latRef = ($Places | ForEach-Object { $_.Lat } | Measure-Object -Average).Average
        $cosLat = [math]::Cos($latRef * [math]::PI / 180.0)
        if ([math]::Abs($cosLat) -lt 1e-6) { $cosLat = 1e-6 }

        $lonStep = $MeshKm / (111.0 * $cosLat)

        return @{ LatStep = $latStep; LonStep = $lonStep }
    }

    # --- サイズ超過時の四分割（再帰） ---
    function Split-Quad {
        param([array]$Indices, [array]$Places, [int]$MaxGroupSize)

        if ($Indices.Count -le $MaxGroupSize) {
            return @([PSCustomObject]@{ Cluster = @($Indices) })
        }

        $latList = $Indices | ForEach-Object { $Places[$_].Lat }
        $lonList = $Indices | ForEach-Object { $Places[$_].Lon }

        $latMid = ($latList | Measure-Object -Average).Average
        $lonMid = ($lonList | Measure-Object -Average).Average

        $nw = @()
        $ne = @()
        $sw = @()
        $se = @()

        foreach ($i in $Indices) {
            $p = $Places[$i]
            if ($p.Lat -ge $latMid -and $p.Lon -lt $lonMid) { $nw += $i; continue }
            if ($p.Lat -ge $latMid -and $p.Lon -ge $lonMid) { $ne += $i; continue }
            if ($p.Lat -lt $latMid -and $p.Lon -lt $lonMid) { $sw += $i; continue }
            if ($p.Lat -lt $latMid -and $p.Lon -ge $lonMid) { $se += $i; continue }
        }

        $result = @()
        foreach ($sub in @($nw, $ne, $sw, $se)) {
            if ($sub.Count -gt 0) {
                $result += Split-Quad -Indices $sub -Places $Places -MaxGroupSize $MaxGroupSize
            }
        }

        return $result 
    }

    # --- メッシュ幅を計算 ---
    $steps = Get-MeshSteps -Places $Places -MeshKm $MeshKm
    $latStep = $steps.LatStep
    $lonStep = $steps.LonStep

    # --- 全体の範囲 ---
    $minLat = ($Places | ForEach-Object { $_.Lat } | Measure-Object -Minimum).Minimum
    $maxLat = ($Places | ForEach-Object { $_.Lat } | Measure-Object -Maximum).Maximum
    $minLon = ($Places | ForEach-Object { $_.Lon } | Measure-Object -Minimum).Minimum
    $maxLon = ($Places | ForEach-Object { $_.Lon } | Measure-Object -Maximum).Maximum

    $clusters = [System.Collections.ArrayList]::new()

    # --- メッシュ走査 ---
    for ($lat = $minLat; $lat -le $maxLat; $lat += $latStep) {
        for ($lon = $minLon; $lon -le $maxLon; $lon += $lonStep) {

            # このメッシュに入る index を集める
            $bucket = @()
            for ($i = 0; $i -lt $Places.Count; $i++) {
                $p = $Places[$i]
                if ($p.Lat -ge $lat -and $p.Lat -lt ($lat + $latStep) -and
                    $p.Lon -ge $lon -and $p.Lon -lt ($lon + $lonStep)) {
                    $bucket += $i
                }
            }

            if ($bucket.Count -eq 0) { continue }

            # サイズ超過なら四分割
            if ($bucket.Count -gt $MaxGroupSize) {
                $subcls = Split-Quad -Indices $bucket -Places $Places -MaxGroupSize $MaxGroupSize
                $subcls | ForEach-Object { [void]$clusters.Add(@($_.Cluster)) }
            }
            else {
                [void]$clusters.Add(@($bucket))
            }
        }
    }
    return $clusters.ToArray()
}


function Cluster-KMeans {
    param(
        [array]$Places,   # @{lat; lon}
        [int]$K = 20
    )

    # --- K の安全化 ---
    if ($Places.Count -lt $K) {
        $K = $Places.Count
    }

    # --- 初期中心（重複なし）---
    $centers = $Places | Get-Random -Count $K -Unique

    # 念のためユニーク数が K 未満なら補完
    while ($centers.Count -lt $K) {
        $centers += ($Places | Get-Random -Count 1)
        $centers = $centers | Select-Object -Unique
    }

    for ($iter = 0; $iter -lt 20; $iter++) {

        # --- 常に K 個のクラスタを作る ---
        $clusters = @(for ($i = 0; $i -lt $K; $i++) { @() })

        # --- 割り当て ---
        for ($i = 0; $i -lt $Places.Count; $i++) {
            $p = $Places[$i]
            $best = 0
            $bestDist = [double]::MaxValue

            for ($c = 0; $c -lt $K; $c++) {
                $d = ([math]::Pow($p.lat - $centers[$c].lat, 2) +
                      [math]::Pow($p.lon - $centers[$c].lon, 2))

                if ($d -lt $bestDist) {
                    $bestDist = $d
                    $best = $c
                }
            }

            # --- 絶対に範囲外にならないガード ---
            if ($best -lt 0 -or $best -ge $K) {
                throw "KMeans internal error: best=$best K=$K"
            }

            $clusters[$best] += $i
        }

        # --- 中心更新 ---
        for ($c = 0; $c -lt $K; $c++) {
            if ($clusters[$c].Count -eq 0) { continue }

            $lat = ($clusters[$c] | ForEach-Object { $Places[$_].lat } | Measure-Object -Average).Average
            $lon = ($clusters[$c] | ForEach-Object { $Places[$_].lon } | Measure-Object -Average).Average

            $centers[$c] = @{ lat = $lat; lon = $lon }
        }
    }

    return $clusters
}
function Cluster-QuadTree {
    param(
        [array]$Places,       # @{lat; lon}
        [int]$MaxGroupSize = 50
    )

    function Split-Quad {
        param([array]$Indices)

        if ($Indices.Count -le $MaxGroupSize) {
            return @($Indices)
        }

        $latMid = ($Indices | % { $Places[$_].lat } | Measure -Average).Average
        $lonMid = ($Indices | % { $Places[$_].lon } | Measure -Average).Average

        $nw = @()
        $ne = @()
        $sw = @()
        $se = @()

        foreach ($i in $Indices) {
            $p = $Places[$i]
            if ($p.lat -ge $latMid -and $p.lon -lt $lonMid) { $nw += $i; continue }
            if ($p.lat -ge $latMid -and $p.lon -ge $lonMid) { $ne += $i; continue }
            if ($p.lat -lt $latMid -and $p.lon -lt $lonMid) { $sw += $i; continue }
            if ($p.lat -lt $latMid -and $p.lon -ge $lonMid) { $se += $i; continue }
        }

        $result = @()
        foreach ($sub in @($nw, $ne, $sw, $se)) {
            if ($sub.Count -gt 0) {
                $result += Split-Quad $sub
            }
        }
        return $result
    }

    return Split-Quad (0..($Places.Count - 1))
}

function Cluster-DBSCAN {
    param(
        [array]$Places,   # @{lat; lon}
        [double]$Eps = 0.01,
        [int]$MinPts = 5
    )

    $N = $Places.Count
    $visited = New-Object bool[] $N
    $clusterId = New-Object int[] $N
    $current = 1

    function Neighbors($i) {
        $p = $Places[$i]
        $res = @()
        for ($j = 0; $j -lt $N; $j++) {
            if ($i -eq $j) { continue }
            $q = $Places[$j]
            $d = [math]::Sqrt(([math]::Pow($p.lat - $q.lat,2) +
                               [math]::Pow($p.lon - $q.lon,2)))
            if ($d -lt $Eps) { $res += $j }
        }
        return $res
    }

    for ($i = 0; $i -lt $N; $i++) {
        if ($visited[$i]) { continue }
        $visited[$i] = $true

        $nbr = Neighbors $i
        if ($nbr.Count -lt $MinPts) { continue }

        $clusterId[$i] = $current
        $queue = [System.Collections.Queue]::new()
        $nbr | % { $queue.Enqueue($_) }

        while ($queue.Count -gt 0) {
            $j = $queue.Dequeue()
            if (-not $visited[$j]) {
                $visited[$j] = $true
                $nbr2 = Neighbors $j
                if ($nbr2.Count -ge $MinPts) {
                    $nbr2 | % { $queue.Enqueue($_) }
                }
            }
            if ($clusterId[$j] -eq 0) {
                $clusterId[$j] = $current
            }
        }

        $current++
    }

    # clusterId → index list
    $clusters = @{}
    for ($i = 0; $i -lt $N; $i++) {
        $cid = $clusterId[$i]
        if ($cid -eq 0) { continue }
        if (-not $clusters.ContainsKey($cid)) { $clusters[$cid] = @() }
        $clusters[$cid] += $i
    }

    return $clusters.Values
}

$towns = [GPXService]::FromCityTowns("岐阜市")
$places = $towns.GetTrkpts() | ForEach-Object {
    [ValueTuple[double, double]]::new($_.lat, $_.lon)
}
$state = @{}

Measure-ClusterEvaluation -Places $places -State $state -ClusterFunc ${Function:Cluster-Mesh}
#Measure-ClusterEvaluation -Places $places -State $state -ClusterFunc ${Function:Cluster-KMeans}


