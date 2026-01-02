using module D:\tool\Repository\PSTools\GPXTools


# GALogic.ps1
# 命名規則整理版
# Run 層でクラスタ化→クラスタ内世代交代→クラスタ間世代交代→結果フィードバックを行う


# =============================================================================
# 2. ルート構築・操作 (New-Route / Invoke-Mutation)
# =============================================================================

function Invoke-MutationSwap {
    param([int[]]$Route)

    $new = $Route.Clone()
    ($i, $j) = Get-Random -Minimum 0 -Maximum $new.Count | Sort-Object

    $tmp = $new[$i]
    $new[$i] = $new[$j]
    $new[$j] = $tmp

    return $new
}

function Select-Tournament {
    param(
        [array]$Population,
        [Int64[, ]]$Dist,
        [int]$K = 3
    )

    $candidates = 1..$K | ForEach-Object {
        Get-Random -InputObject $Population
    }
    return ($candidates | Sort-Object { [TspSolverLib.DistanceBuilder]::GetRouteDistance($_, $Dist) })[0]
}

function Invoke-CrossoverOX {
    param(
        [int[]]$A,
        [int[]]$B
    )

    $size = $A.Count
    $child = @(foreach ($i in 1..$size) { $null })

    # ★ 修馬さん指定のランダム区間
    ($i, $j) = Get-Random -Minimum 0 -Maximum $size | Sort-Object

    # A の区間をコピー
    for ($k = $i; $k -le $j; $k++) {
        $child[$k] = $A[$k]
    }

    # B の順序で残りを埋める
    $pos = ($j + 1) % $size
    foreach ($city in $B) {
        if ($child -notcontains $city) {
            $child[$pos] = $city
            $pos = ($pos + 1) % $size
        }
    }

    return $child
}

    
# =============================================================================
# 4. GA ロジック (New-Generation / Invoke-Simulation)
# =============================================================================   
function New-InitialPopulation {
    param(
        [int]$PopSize,
        [int[]]$Indices,          # クラスタのノード集合（グローバル index）
        [long[, ]]$GlobalMatrix,   # 全体距離行列
        [double]$EliteRatio = 0.2,
        [double]$LocalOptRatio = 0.3
    )

    $n = $Indices.Count
    $population = @()

    # 1. エリート（SolveSubset）
    $eliteCount = [math]::Floor($PopSize * $EliteRatio)
    for ($i = 0; $i -lt $eliteCount; $i++) {
        $route = [TspSolverLib.OrToolsTsp]::SolveSubset($GlobalMatrix, $Indices, 0)
        $population += , $route
    }

    # 2. 準エリート（SolveSegment）
    $localOptCount = [math]::Floor($PopSize * $LocalOptRatio)
    for ($i = 0; $i -lt $localOptCount; $i++) {
        $base = [TspSolverLib.OrToolsTsp]::SolveSubset($GlobalMatrix, $Indices, 0)
        #        $opt = [TspSolverLib.OrToolsTsp]::SolveSegment($GlobalMatrix, $base, 100, 200)
        $population += , $base
    }

    # 3. ランダム（多様性）
    $randomCount = $PopSize - $eliteCount - $localOptCount
    for ($i = 0; $i -lt $randomCount; $i++) {
        $population += , ($Indices | Sort-Object { Get-Random })
    }

    return $population
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
function New-NextGeneration {
    param(
        [array]$Population,
        [long[, ]]$Matrix,
        [double]$MutationRate = 0.3,
        [double]$EliteReserveRate = 0.1,
        [double]$LocalOptRate = 0.1
    )

    if ($Population.Count -eq 0 -or $Population[0].Count -le 1) {
        return $Population
    }

    $popSize = $Population.Count

    # 1. 評価してソート
    $sortedCurrent = $Population | Sort-Object {
        [TspSolverLib.DistanceBuilder]::GetRouteDistance($_, $Matrix)
    }

    # 2. エリート数
    $eliteCount = [math]::Floor($popSize * $EliteReserveRate)
    if ($eliteCount -lt 1) { $eliteCount = 1 }

    # 3. エリートコピー
    $next = @()
    $elites = $sortedCurrent[0..($eliteCount - 1)]
    foreach ($e in $elites) {
        $next += , ($e.Clone())
    }

    # 3.5 エリート改善（SolveSegment）
    for ($idx = 1; $idx -lt $eliteCount; $idx++) {
        $route = $next[$idx]

        ($i, $j) = Get-Random -Minimum 0 -Maximum $route.Count | Sort-Object
        if ($i -lt $j) {
            $next[$idx] =
            [TspSolverLib.OrToolsTsp]::SolveSegment(
                $GlobalMatrix,
                $route,
                $i,
                $j
            )
        }
    }

    # 4. 残りを生成
    while ($next.Count -lt $popSize) {

        # 親選択
        $parentA = Select-Tournament $Population $Matrix
        $parentB = Select-Tournament $Population $Matrix

        # 交叉
        $child = Invoke-CrossoverOX $parentA $parentB

        # Swap Mutation
        if ((Get-Random) -lt $MutationRate) {
            $child = Invoke-MutationSwap $child
        }

        # 5. SolveSegment Mutation（Greedy Mutation の代替）
        if ((Get-Random) -lt $LocalOptRate) {
            ($i, $j) = Get-Random -Minimum 0 -Maximum $child.Count | Sort-Object
            if ($i -lt $j) {
                $child =
                [TspSolverLib.OrToolsTsp]::SolveSegment(
                    $GlobalMatrix,
                    $child,
                    $i,
                    $j
                )
            }
        }
        $next += , $child
    }
    # 6. 次世代をソートして返す
    return ($next | Sort-Object {
            [TspSolverLib.DistanceBuilder]::GetRouteDistance($_, $Matrix)
        })
}

function Cluster-Simple {
    param(
        [Parameter(Mandatory)]
        [array]$Places,

        [int]$MaxGroupSize = 50
    )

    # 1. index と lat をセットにしてソート
    $indexed = for ($i = 0; $i -lt $Places.Count; $i++) {
        [PSCustomObject]@{
            Index = $i
            Lat   = $Places[$i].Lat
        }
    }

    $sorted = $indexed | Sort-Object Lat

    # 2. MaxGroupSize ごとに切る
    $clusters = @()
    for ($i = 0; $i -lt $sorted.Count; $i += $MaxGroupSize) {
        $slice = $sorted[$i..([Math]::Min($i + $MaxGroupSize - 1, $sorted.Count - 1))]
        $indices = $slice.Index | ForEach-Object { [int]$_ }
        $clusters += , ([int[]]$indices)
    }

    return $clusters
}

    
function Invoke-GASimulation {
    param(
        [array]     $Places,
        [hashtable] $State,          # 呼び出し側で作成して渡す
        [int]       $PopSizePerCluster = 50,
        [int]       $PopSizeClustersOrder = 50,
        [int]       $MaxGen = 1000,
        [int]       $NumClusters = 10
    )
    
    # ★時間計測用ストップウォッチ開始
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    # ★パフォーマンス情報を格納する場所を作る
    if (-not $State.ContainsKey('Performance')) {
        $State.Performance = @{
            InitTime       = 0
            ClusterGATime  = 0
            MatrixCalcTime = 0
            OrderGATime    = 0
            EvalTime       = 0
            TotalLoopTime  = 0
        }
    }

    # --- フェーズ: 初期化開始 ---
    $State.Phase = "Init"
    
    # 1. グローバル距離行列（C#）
    if (-not $State.ContainsKey('GlobalDist')) {
        $State.GlobalDist = [TspSolverLib.DistanceBuilder]::BuildGlobalMatrix($Places)
    }
    
    # --- フェーズ: クラスタ初期化 ---
    if (-not $State.ContainsKey('ClusterData')) {
        $State.Phase = "ClusterInit"
        
        $initStart = $sw.ElapsedMilliseconds

        # 2. クラスタ生成（Places -> Indices のクラスタ）
 #       $clusters = Cluster-Mesh -Places ($places | ForEach-Object { @{lat = $_.Item1; lon = $_.Item2 } })
        $clusters = Cluster-Simple -Places ($places | ForEach-Object { @{lat = $_.Item1; lon = $_.Item2 } })
        $cd = @()
    
        for ($ci = 0; $ci -lt $clusters.Count; $ci++) {
            $inds = $clusters[$ci]   # グローバルIndexの配列 (int[])

            # ★ここが重要：
            #   - Greedy ではなく、TSP 解を混ぜた初期集団を作る
            #   - New-InitialPopulation の中で SolveSubset / SolveSegment を使う実装にしておく
            $pop = New-InitialPopulation `
                -PopSize      $PopSizePerCluster `
                -Indices      $inds `
                -GlobalMatrix $State.GlobalDist

            # 評価は常に GlobalDist で行う
            $sortedPop = $pop | Sort-Object { [TspSolverLib.DistanceBuilder]::GetRouteDistance($_, $State.GlobalDist) }
            $bestRoute = $sortedPop[0]
            $bestDist = [TspSolverLib.DistanceBuilder]::GetRouteDistance($bestRoute, $State.GlobalDist)
    
            $cd += , [PSCustomObject]@{
                Indices         = $inds              # クラスタに属するノードの集合（グローバルIndex）
                Population      = $sortedPop        # ルートは全てグローバルIndex列
                BestRouteGlobal = $bestRoute
                BestDist        = $bestDist
            }
        }
    
        $State.ClusterData = $cd
    
        # 3. クラスタ「順序」初期化
        Write-Host "  3. Initializing Inter-Cluster Order..."

        $bestRoutes = @(
            $State.ClusterData | ForEach-Object {
                [int[]]$_.BestRouteGlobal
            }
        )
        # 「出口→入口」距離行列（C#）
        $clusterDistMatrix =
        [TspSolverLib.ClusterMatrixBuilder]::NewClusterDistanceMatrix(
            $bestRoutes,
            $State.GlobalDist
        )

        # クラスタ順序: 初期集団生成
        # ここも Greedy はやめて、単なる順列生成用に使うか、
        # あるいは Order 用にも TSP 解を混ぜる New-InitialPopulationVariant を用意する。
        $orderPop = New-InitialPopulation `
            -PopSize      $PopSizeClustersOrder `
            -Indices      (0..($State.ClusterData.Count - 1)) `
            -GlobalMatrix $clusterDistMatrix

        # 順序を評価してソート（距離行列は clusterDistMatrix）
        $sortedOrderPop = $orderPop | Sort-Object {
            [TspSolverLib.DistanceBuilder]::GetRouteDistance($_, $clusterDistMatrix)
        }
    
        $State.ClusterOrderPopulation = $sortedOrderPop
        $State.BestClusterOrder = $sortedOrderPop[0]

        # -----------------------------------------------------------
        # 初期状態の BestDist と BestRoute を確定
        # -----------------------------------------------------------
        $fullRoute = @()
        foreach ($cIdx in $State.BestClusterOrder) {
            $fullRoute += $State.ClusterData[$cIdx].BestRouteGlobal
        }
        $State.BestRoute = $fullRoute
        $State.BestDist = [TspSolverLib.DistanceBuilder]::GetRouteDistance($State.BestRoute, $State.GlobalDist)

        # メタ情報設定
        $State.Generation = 0
        $State.UpdatedAt = (Get-Date).ToUniversalTime()

        # ★初期化時間の記録
        $initEnd = $sw.ElapsedMilliseconds
        $State.Performance.InitTime = $initEnd - $initStart

        Write-Host "    Initial Total Distance: $($State.BestDist)" -ForegroundColor Yellow
        Write-Host "    Initialization Time   : $($State.Performance.InitTime) ms" -ForegroundColor Cyan
        Write-Host "    Initial Best Order    : $($State.BestClusterOrder -join ' -> ')" -ForegroundColor Gray
    }
        
    # --- フェーズ: GA 実行 ---
    while (-not $State.Stop) {
        
        # ★ループ内計測開始
        $t_start = $sw.ElapsedMilliseconds

        # 1) クラスタ内 GA
        $State.Phase = "ClusterGA"
        for ($ci = 0; $ci -lt $State.ClusterData.Count; $ci++) {
            $c = $State.ClusterData[$ci]
    
            if ($c.Indices.Count -gt 1) {
                # ★ New-NextGeneration は Dist に long[,] を取る設計にしておく
                #   - ここでは GlobalDist を渡す
                $c.Population = New-NextGeneration `
                    -Population $c.Population `
                    -Matrix $State.GlobalDist
            }

            $bestRoute = $c.Population[0]
            $c.BestRouteGlobal = $bestRoute
            $c.BestDist = [TspSolverLib.DistanceBuilder]::GetRouteDistance($bestRoute, $State.GlobalDist)
        }
        $t_clusterGA = $sw.ElapsedMilliseconds
    
        # 2) クラスタ間距離行列（C#）
        $State.Phase = "OrderGA"
        $bestRoutes = @(
            $State.ClusterData | ForEach-Object {
                [int[]]$_.BestRouteGlobal
            }
        )
        $clusterDist =
        [TspSolverLib.ClusterMatrixBuilder]::NewClusterDistanceMatrix(
            $bestRoutes,
            $State.GlobalDist
        )
        
        $t_matrix = $sw.ElapsedMilliseconds

        # 3) クラスタ順序 GA
        #    - Dist に clusterDist（クラスタ距離行列）を渡す
        $State.ClusterOrderPopulation = New-NextGeneration `
            -Population $State.ClusterOrderPopulation `
            -Matrix       $clusterDist
        
        $t_orderGA = $sw.ElapsedMilliseconds

        # 4) 全体ルート評価
        $State.Phase = "Evaluate"
        $bestOrder = $State.ClusterOrderPopulation[0]
    
        $finalRoute = @()
        foreach ($ci in $bestOrder) {
            $finalRoute += $State.ClusterData[$ci].BestRouteGlobal
        }

        # ここでさらに C# の SolveSegment をかけて
        # GA の結果を局所最適化してもいい（任意）:
        # $finalRoute = [TspSolverLib.OrToolsTsp]::SolveSegment(
        #     $State.GlobalDist,
        #     $finalRoute,
        #     0,
        #     $finalRoute.Count
        # )

        $finalDist = [TspSolverLib.DistanceBuilder]::GetRouteDistance($finalRoute, $State.GlobalDist)
    
        # 5) State 更新
        $State.Generation++
        $State.BestRoute = $finalRoute
        $State.BestDist = $finalDist
        $State.UpdatedAt = (Get-Date).ToUniversalTime()
        
        $t_eval = $sw.ElapsedMilliseconds

        # ★計測結果をStateに保存（差分計算）
        $State.Performance.ClusterGATime = $t_clusterGA - $t_start
        $State.Performance.MatrixCalcTime = $t_matrix - $t_clusterGA
        $State.Performance.OrderGATime = $t_orderGA - $t_matrix
        $State.Performance.EvalTime = $t_eval - $t_orderGA
        $State.Performance.TotalLoopTime = $t_eval - $t_start

        Write-Host "Gen: $($State.Generation) | Dist: $($State.BestDist.ToString('0.00')) | Time: $($State.Performance.TotalLoopTime)ms [Cluster:$($State.Performance.ClusterGATime) Order:$($State.Performance.OrderGATime)]" -ForegroundColor Gray
      
        # 6) 終了判定
        if ($State.Generation -ge $MaxGen) { break }
    }
    
    # --- フェーズ: 完了 ---
    $State.Phase = "Finished"
    $sw.Stop()
    
    return $State
}
    
# -----------------------
# テストラッパー
# -----------------------
function Test-GASimulation {
    param(
        [object] $Places = $null,
        [int] $N = 100,
        [int] $NumClusters = 50,
        [int] $PopSizePerCluster = 50,
        [int] $PopSizeClustersOrder = 100,
        [int] $MaxGen = 50
    )
    
    if (-not $Places) {
        $Places = 1..$N | ForEach-Object { [PSCustomObject]@{ lat = Get-Random -Minimum 33.5 -Maximum 33.6; lon = Get-Random -Minimum 134.0 -Maximum 134.1 } }
    }

    $state = @{
        Stop = $false
    }
    
    Invoke-GASimulation -Places $Places -State $state -NumClusters $NumClusters -PopSizePerCluster $PopSizePerCluster -PopSizeClustersOrder $PopSizeClustersOrder -MaxGen $MaxGen
    "Gen: $($state.Generation), BestDist: $([math]::Round($state.BestDist,3))"
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
        $clusters += ,($i..$end)
    }
    return $clusters
}

$towns = [GPXService]::FromCityTowns("横須賀市")
$places = $towns.GetTrkpts() | ForEach-Object {
    [ValueTuple[double, double]]::new($_.lat, $_.lon)
}
$state = @{}

Invoke-GASimulation -Places $Places -State $state -MaxGen 100
