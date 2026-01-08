using module D:\tool\Repository\PSTools\GPXTools

function Invoke-GASimulation {
    param(
        [array]     $Places,
        [hashtable] $State,
        [int]       $PopSizeOrder = 50,
        [int]       $MaxGen = 1000
    )

    Write-Host "=== Init Phase ==="

    # -------------------------
    # Init Phase
    # -------------------------
    $State.Phase = "Init"

    # 1. グローバル距離行列
    Write-Host "[Init] Building global distance matrix..."
    $State.GlobalDist = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($Places)

    # 2. クラスタ分割
    Write-Host "[Init] Clustering places..."
    $State.Clusters = Cluster-Simple -Places $Places
    $numClusters = $State.Clusters.Count
    Write-Host "[Init] Clusters: $numClusters"

    # 3. 初期集団（Order + ClusterRoutes）
    Write-Host "[Init] Creating initial population..."
    $population = @()

    for ($i = 0; $i -lt $PopSizeOrder; $i++) {

        $order = (0..($numClusters - 1)) | Sort-Object { Get-Random }

        $clusterRoutes = @{}
        foreach ($cid in 0..($numClusters - 1)) {
            $nodes = $State.Clusters[$cid]
            $clusterRoutes[$cid] = $nodes | Sort-Object { Get-Random }
        }

        $individual = [pscustomobject]@{
            Order         = $order
            ClusterRoutes = $clusterRoutes
        }

        $population += $individual
    }

    $State.OrderPopulation = $population

    # 4. 初期評価
    Write-Host "[Init] Evaluating initial population..."

    $best = $null

    foreach ($ind in $State.OrderPopulation) {

        $order = $ind.Order
        $clusterRoutes = $ind.ClusterRoutes

        $globalRoute = @()
        $prevEnd = $null

        foreach ($clusterId in $order) {
            $route = $clusterRoutes[$clusterId]
            $globalRoute += $route
            $prevEnd = $route[-1]
        }

        $dist = 0
        for ($i = 0; $i -lt $globalRoute.Count - 1; $i++) {
            $dist += $State.GlobalDist[$globalRoute[$i], $globalRoute[$i + 1]]
        }

        if ($best -eq $null -or $dist -lt $best.Dist) {
            $best = [pscustomobject]@{
                Order = $order
                Route = $globalRoute
                Dist  = $dist
            }
        }
    }

    Write-Host "[Init] Best initial distance: $($best.Dist)"

    $State.BestOrder = $best.Order
    $State.BestRoute = $best.Route
    $State.BestDist = $best.Dist
    $State.Generation = 0


    # -------------------------
    # GA Loop
    # -------------------------
    Write-Host "=== GA Phase ==="

    while (-not $State.Stop -and $State.Generation -lt $MaxGen) {

        $State.Phase = "GA"

        # 1. 次世代生成
        $State.OrderPopulation = New-NextGeneration `
            -Population $State.OrderPopulation `
            -Clusters   $State.Clusters `
            -GlobalDist $State.GlobalDist

        # 2. 評価
        $best = Evaluate-Population `
            -Population $State.OrderPopulation `
            -Clusters   $State.Clusters `
            -GlobalDist $State.GlobalDist

        # 3. ベスト更新
        $State.BestOrder = $best.Order
        $State.BestRoute = $best.Route
        $State.BestDist = $best.Dist

        # --- ログ出力 ---
        if ($State.Generation % 10 -eq 0) {
            Write-Host "[Gen $($State.Generation)] BestDist = $($State.BestDist)"
        }

        $State.Generation++
    }

    Write-Host "=== Finished ==="
    Write-Host "Best Distance: $($State.BestDist)"

    $State.Phase = "Finished"
    return $State
}
function Evaluate-Population {
    param(
        [array] $Population,     # 個体 = { Order, ClusterRoutes }
        [array] $Clusters,
        [array] $GlobalDist
    )

    $best = $null

    foreach ($ind in $Population) {

        $order = $ind.Order
        $clusterRoutes = $ind.ClusterRoutes

        # --- 全体ルート構築 ---
        $globalRoute = @()
        $prevEnd = $null

        foreach ($cid in $order) {

            # 個体が保持しているクラスタ内順序を使う
            $route = $clusterRoutes[$cid]

            # 入口固定が必要ならここで調整（今はそのまま）
            # ※必要なら後で追加

            $globalRoute += $route
            $prevEnd = $route[-1]
        }

        # --- 距離計算 ---
        $dist = 0
        for ($i = 0; $i -lt $globalRoute.Count - 1; $i++) {
            $dist += $GlobalDist[$globalRoute[$i], $globalRoute[$i + 1]]
        }

        # --- ベスト更新 ---
        if ($best -eq $null -or $dist -lt $best.Dist) {
            $best = [pscustomobject]@{
                Order = $order
                Route = $globalRoute
                Dist  = $dist
            }
        }
    }

    return $best
}
function Split-Clusters {
    param(
        [array] $Places,
        [int]   $NumClusters = 10
    )

    $clusters = @()
    $chunkSize = [math]::Ceiling($Places.Count / $NumClusters)

    for ($i = 0; $i -lt $Places.Count; $i += $chunkSize) {
        $end = [math]::Min($i + $chunkSize - 1, $Places.Count - 1)
        $clusters += , ($i..$end)
    }

    return $clusters
}


function New-NextGeneration {
    param(
        [array] $Population,     # 個体 = { Order, ClusterRoutes }
        [array] $Clusters,   # cid => [nodes]
        [array] $GlobalDist,
        [double] $mutationRate = 0.1
    )

    $newPop = @()
    $numClusters = $Clusters.Count

    # ---- 親選択（ランダム or トーナメント） ----
    function Select-Parent {
        return $Population[(Get-Random -Minimum 0 -Maximum $Population.Count)]
    }

    # ---- エリート保存（最良1個体） ----
    $elite = $Population | Sort-Object { $_.Fitness } | Select-Object -First 1
    $newPop += $elite

    # ---- 残りを生成 ----
    for ($i = 1; $i -lt $Population.Count; $i++) {

        $p1 = Select-Parent
        $p2 = Select-Parent

        # -------------------------
        # 1. Order の交叉（OX）
        # -------------------------
        $childOrder = Invoke-OX -ParentA $p1.Order -ParentB $p2.Order

        # -------------------------
        # 2. Order の突然変異
        # -------------------------
        if ((Get-Random) -lt $mutationRate) {
            $childOrder = Invoke-SwapMutation -Order $childOrder
        }

        # -------------------------
        # 3. ClusterRoutes を再構築
        #    Order の変更点以降すべて TSP
        # -------------------------
        $childRoutes = @{}

        # 変更点を検出
        $changedIndex = 0
        for ($k = 0; $k -lt $numClusters; $k++) {
            if ($childOrder[$k] -ne $p1.Order[$k]) {
                $changedIndex = $k
                break
            }
        }

        # 変更点より前は親のルートを継承
        for ($k = 0; $k -lt $changedIndex; $k++) {
            $cid = $childOrder[$k]
            $childRoutes[$cid] = $p1.ClusterRoutes[$cid].Clone()
        }

        # 変更点以降は TSP で再最適化
        for ($k = $changedIndex; $k -lt $numClusters; $k++) {

            $cid = $childOrder[$k]

            # 入口
            if ($k -eq 0) {
                $entry = $null
            }
            else {
                $prevCid = $childOrder[$k - 1]
                $entry = $childRoutes[$prevCid][-1]
            }

            # 出口は次クラスタの入口が決まるまで null
            $exit = $null

            $childRoutes[$cid] = Invoke-ClusterTsp `
                -Nodes $Clusters[$cid] `
                -Entry $entry `
                -Exit $exit `
                -GlobalDist $GlobalDist
        }

        # -------------------------
        # 4. 個体としてまとめる
        # -------------------------
        $child = [pscustomobject]@{
            Order         = $childOrder
            ClusterRoutes = $childRoutes
        }

        $newPop += $child
    }

    return $newPop
}

function Invoke-OX {
    param(
        [int[]] $ParentA,
        [int[]] $ParentB
    )

    $size = $ParentA.Count
    $child = @(foreach ($i in 0..($size - 1)) { $null })

    # ランダム区間
    $start = Get-Random -Minimum 0 -Maximum $size
    $end = Get-Random -Minimum $start -Maximum $size

    # A の区間をコピー
    for ($i = $start; $i -lt $end; $i++) {
        $child[$i] = $ParentA[$i]
    }

    # B の順序で埋める
    $pos = $end
    foreach ($g in $ParentB) {
        if ($child -notcontains $g) {
            if ($pos -ge $size) { $pos = 0 }
            $child[$pos] = $g
            $pos++
        }
    }

    return $child
}
function Invoke-SwapMutation {
    param([int[]] $Order)

    $i = Get-Random -Minimum 0 -Maximum $Order.Count
    $j = Get-Random -Minimum 0 -Maximum $Order.Count

    $tmp = $Order[$i]
    $Order[$i] = $Order[$j]
    $Order[$j] = $tmp

    return $Order
}
function Invoke-ClusterTsp {
    param(
        [int[]] $Nodes,
        [int]   $Entry,
        [int]   $Exit,
        [array] $GlobalDist
    )

    $inner = $Nodes | Where-Object { $_ -ne $Entry -and $_ -ne $Exit }

    $route = @()

    if ($Entry -ne $null) { $route += $Entry }

    $current = $Entry
    $remain = $inner.Clone()

    while ($remain.Count -gt 0) {
        if ($current -eq $null) {
            $next = $remain[0]
        }
        else {
            $next = ($remain | Sort-Object { $GlobalDist[$current, $_] })[0]
        }
        $route += $next
        $remain = $remain | Where-Object { $_ -ne $next }
        $current = $next
    }

    if ($Exit -ne $null) { $route += $Exit }

    return $route
}

$towns = [GPXService]::FromCityTowns("上越市")
$places = $towns.GetTrkpts() | ForEach-Object {
    [ValueTuple[double, double]]::new($_.lat, $_.lon)
}
$state = @{}

#Invoke-GASimulation -Places $Places -State $state -MaxGen 100

function Measure-GASimulation {
    param(
        [array]     $Places,
        [hashtable] $State,
        [int]       $PopSizeOrder = 50,
        [int]       $MaxGen = 1000
    )

    Write-Host "=== Init Phase ==="

    # -------------------------
    # Init Phase
    # -------------------------
    $State.Phase = "Init"

    # 1. グローバル距離行列
    Write-Host "[Init] Building global distance matrix..."
    $State.GlobalDist = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($Places)

    # 2. クラスタ分割
    Write-Host "[Init] Clustering places..."
    $State.Clusters = Cluster-Mesh -Places ($places | %{@{lat=$_.Item1;lon=$_.Item2}})
    $numClusters = $State.Clusters.Count
    Write-Host "[Init] Clusters: $numClusters"

    # 3. 初期集団（Order + ClusterRoutes）
    Write-Host "[Init] Creating initial population..."
    $population = @()

    for ($i = 0; $i -lt $PopSizeOrder; $i++) {
        $order = (0..($numClusters - 1)) | Sort-Object { Get-Random }
        $clusterRoutes = @{}
        foreach ($cid in 0..($numClusters - 1)) {
            $nodes = $State.Clusters[$cid]
            $clusterRoutes[$cid] = $nodes | Sort-Object { Get-Random }
        }
        $individual = [pscustomobject]@{
            Order         = $order
            ClusterRoutes = $clusterRoutes
        }
        $population += $individual
    }

    $State.OrderPopulation = $population

    # 4. フルTSP（クラスタなし）での距離
    Write-Host "[Init] Evaluating initial population..."
    $best = $null

    Write-Host "[Init] Running full TSP without clustering..."

    # 全ノード TSP
    $fullRoute = [TspSolverLib.OrToolsTsp]::SolveFull($State.GlobalDist)

    # 距離計算
    $fullDist = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
        $fullRoute,
        $State.GlobalDist
    )

    Write-Host "[FullTSP] Route = $($fullRoute -join ',')"
    Write-Host "[FullTSP] Distance = $fullDist"

    # --- 初期集団のパイプライン 1〜4 を計測 ---
    Write-Host "[Init] Measuring cluster / order TSP pipeline for initial population..."

    foreach ($ind in $State.OrderPopulation) {

        $order1  = $ind.Order            # Step1 の Order（ランダム）
        $routes1 = $ind.ClusterRoutes    # Step1 のクラスタ内ルート（ランダム）

        # ============================
        # Step 1: Orderランダム + クラスタ内ランダム
        # ============================
        $globalRoute1 = @()
        foreach ($cid in $order1) {
            $globalRoute1 += $routes1[$cid]
        }
        $dist1 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $globalRoute1,
            $State.GlobalDist
        )

        # ============================
        # Step 2: 1 にクラスタ内TSP（Orderはそのまま）
        # ============================
        $routes2 = @{}
        foreach ($cid in $order1) {
            $nodes = $State.Clusters[$cid]  # クラスタに属するノード
            # クラスタ内だけのTSP（入口制約なし）
            $routes2[$cid] = [TspSolverLib.OrToolsTsp]::SolveSubset(
                $State.GlobalDist,
                $nodes,
                $null
            )
        }

        $globalRoute2 = @()
        foreach ($cid in $order1) {
            $globalRoute2 += $routes2[$cid]
        }
        $dist2 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $globalRoute2,
            $State.GlobalDist
        )

        # ============================
        # Step 3: クラスタ間のOrder TSP
        # ============================
        # ClusterMatrixBuilder.NewClusterDistanceMatrix(int[][] bestRoutes, long[,] globalDist)
        # に渡すため、クラスタID順の int[] 配列を作る
        $bestRoutesArray = @()
        for ($cid = 0; $cid -lt $numClusters; $cid++) {
            # 各クラスタのルート（なければ元のを使う）
            $routeForCluster = if ($routes2.ContainsKey($cid)) { $routes2[$cid] } else { $routes1[$cid] }
            $bestRoutesArray += ,([int[]]$routeForCluster)
        }

        $clusterDist = [TspSolverLib.ClusterMatrixBuilder]::NewClusterDistanceMatrix(
            $bestRoutesArray,
            $State.GlobalDist
        )

        $clusterIds = 0..($numClusters - 1)

        # クラスタ間のTSP（クラスタID空間での TSP）
        $order3 = [TspSolverLib.OrToolsTsp]::SolveSubset(
            $clusterDist,
            $clusterIds,
            $null
        )

        $globalRoute3 = @()
        foreach ($cid in $order3) {
            $globalRoute3 += $routes2[$cid]
        }
        $dist3 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $globalRoute3,
            $State.GlobalDist
        )

        # ============================
        # Step 4: 3 の Order に対してクラスタ内TSP（前クラスタ終端を入口にする）
        # ============================
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
            if ($route4.Count -gt 0) {
                $prevEnd = $route4[-1]
            }
        }

        $globalRoute4 = @()
        foreach ($cid in $order3) {
            $globalRoute4 += $routes4[$cid]
        }
        $dist4 = [TspSolverLib.DistanceBuilder]::GetRouteDistance(
            $globalRoute4,
            $State.GlobalDist
        )

        Write-Host ("[Pipeline] Order1={0}  Dist1={1}  Dist2={2}  Dist3={3}  Dist4={4}" -f `
            ($order1 -join ","), $dist1, $dist2, $dist3, $dist4)
    }

    # best はここでは使っていないが、既存の構造は残しておく
    Write-Host "[Init] Best initial distance: $($best.Dist)"

    $State.BestOrder = $best.Order
    $State.BestRoute = $best.Route
    $State.BestDist  = $best.Dist
    $State.Generation = 0
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