# GALogic.ps1
# 命名規則整理版
# Run 層でクラスタ化→クラスタ内世代交代→クラスタ間世代交代→結果フィードバックを行う

# =============================================================================
# 1. 距離・測定 (Measure / New-Matrix)
# =============================================================================

function Get-Distance {
    param($p1, $p2)
    $R = 6371
    $dLat = [math]::PI / 180 * ($p2.lat - $p1.lat)
    $dLon = [math]::PI / 180 * ($p2.lon - $p1.lon)
    $lat1 = [math]::PI / 180 * $p1.lat; $lat2 = [math]::PI / 180 * $p2.lat
    $a = [math]::Pow([math]::Sin($dLat / 2), 2) + [math]::Cos($lat1) * [math]::Cos($lat2) * [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

function New-DistanceMatrix {
    param([array]$Places)
    $n = $Places.Count
    $dist = [double[, ]]::new($n, $n)
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = $i; $j -lt $n; $j++) {
            if ($i -eq $j) { $dist[$i, $j] = [double]::PositiveInfinity } else {
                $d = Get-Distance $Places[$i] $Places[$j]
                $dist[$i, $j] = $d; $dist[$j, $i] = $d
            }
        }
    }
    return , $dist
}

function Get-SubMatrix {
    param($globalDist, $indices)
    $m = $indices.Count; $sub = [double[, ]]::new($m, $m)
    for ($i = 0; $i -lt $m; $i++) { for ($j = 0; $j -lt $m; $j++) { $sub[$i, $j] = $globalDist[$indices[$i], $indices[$j]] } }
    return , $sub
}
function Get-RouteDistance {
    param([int[]]$route, [double[, ]]$Dist)
    if ($route.Count -le 1) { return 0.0 }
    $s = 0.0
    for ($i = 0; $i -lt $route.Count - 1; $i++) { $s += $Dist[$route[$i], $route[$i + 1]] }
    return $s
}
function New-ClusterDistanceMatrix {
    param(
        [System.Collections.ArrayList]$ClusterData,
        [double[, ]]$GlobalDist
    )
    $k = $ClusterData.Count
    $mat = [double[, ]]::new($k, $k)
    for ($i = 0; $i -lt $k; $i++) {
        # クラスタ i の出口 (Global Index)
        $exitNode = $ClusterData[$i].BestRouteGlobal[-1]

        for ($j = 0; $j -lt $k; $j++) {
            if ($i -eq $j) {
                # 自分自身への移動は無限大 (Greedyで選ばれないように)
                $mat[$i, $j] = [double]::PositiveInfinity
            }
            else {
                # クラスタ j の入口 (Global Index)
                $entryNode = $ClusterData[$j].BestRouteGlobal[0]
                # 出口 -> 入口 の距離
                $mat[$i, $j] = $GlobalDist[$exitNode, $entryNode]
            }
        }
    }
    return , $mat
}

# =============================================================================
# 2. ルート構築・操作 (New-Route / Invoke-Mutation)
# =============================================================================

function Get-GreedyRoute {
    param(
        [Parameter(Mandatory)]
        [double[, ]]$DistanceMatrix,

        [int[]]$Route = $null,
        
        # 部分Greedy用のパラメータ
        [Nullable[int]]$StartPos = $null,
        [Nullable[int]]$EndPos = $null,

        # 全体Greedyの開始ノードを指定するためのパラメータ（今回追加）
        # $Route内のインデックスを指定する (0 ～ Route.Count-1)
        [int]$FixedStartNodeIndex = 0 
    )

    # 内部関数: インデックス配列に対するGreedy順序生成
    function Get-GreedyOrderInternal {
        param(
            [double[, ]]$DistanceMatrix,
            [int[]]$Nodes,
            [int]$StartIndex = 0
        )
        $n = $Nodes.Count
        $visited = [bool[]]::new($n)
        $visited[$StartIndex] = $true
        $currentNode = $Nodes[$StartIndex]

        $result = New-Object System.Collections.Generic.List[int]
        $result.Add($currentNode)

        for ($step = 1; $step -lt $n; $step++) {
            $nearest = -1
            $minDist = [double]::PositiveInfinity

            for ($i = 0; $i -lt $n; $i++) {
                if (-not $visited[$i]) {
                    $candidate = $Nodes[$i]
                    $d = $DistanceMatrix[$currentNode, $candidate]
                    if ($d -lt $minDist) {
                        $minDist = $d
                        $nearest = $i
                    }
                }
            }
            $visited[$nearest] = $true
            $currentNode = $Nodes[$nearest]
            $result.Add($currentNode)
        }
        return $result.ToArray()
    }

    # --- 1. Route が null → 全体 Greedy ---
    # $DistanceMatrix の次元数ぶんのノード (0..N-1) を対象にする
    if ($Route -eq $null) {
        $n = $DistanceMatrix.GetLength(0)
        $nodes = 0..($n - 1)
        # 渡された FixedStartNodeIndex を開始点として利用
        return Get-GreedyOrderInternal $DistanceMatrix $nodes $FixedStartNodeIndex
    }

    # --- 2. Route 全体 Greedy ---
    # 既存のノードリストを並べ替える
    if ($StartPos -eq $null -and $EndPos -eq $null) {
        # 渡された FixedStartNodeIndex を開始点として利用
        return Get-GreedyOrderInternal $DistanceMatrix $Route $FixedStartNodeIndex
    }

    # --- 3. 区間 Greedy (部分最適化) ---
    # ※区間Greedyの場合は、区間の先頭($segment[0])から始めるのが基本ロジックのため
    #   FixedStartNodeIndex は無視して 0 固定とします。
    if ($StartPos -ne $null -and $EndPos -ne $null) {
        if ($StartPos -lt 0 -or $EndPos -ge $Route.Count -or $StartPos -ge $EndPos) {
            throw "StartPos / EndPos が不正です。"
        }
        $segment = $Route[$StartPos..$EndPos]
        $newSegment = Get-GreedyOrderInternal $DistanceMatrix $segment 0

        $newRoute = @()
        if ($StartPos -gt 0) { $newRoute += $Route[0..($StartPos - 1)] }
        $newRoute += $newSegment
        if ($EndPos -lt $Route.Count - 1) { $newRoute += $Route[($EndPos + 1)..($Route.Count - 1)] }

        return $newRoute
    }

    throw "パラメータの組み合わせが不正です。"
}

function Invoke-MutationSwap {
    param([int[]]$route)
    $len = $route.Count
    if ($len -lt 2) { return $route }
    $a = Get-Random -Minimum 0 -Maximum $len
    $b = Get-Random -Minimum 0 -Maximum $len
    if ($a -ne $b) { $t = $route[$a]; $route[$a] = $route[$b]; $route[$b] = $t }
    return $route
}
    
# =============================================================================
# 4. GA ロジック (New-Generation / Invoke-Simulation)
# =============================================================================   
function New-InitialPopulation {
    param(
        [int]$PopSize,
        [double[, ]]$DistMatrix,   # この行列のサイズ(N)に合わせて 0..N-1 のルートを作る
        [double]$GreedyRatio = 0.5
    )

    $n = $DistMatrix.GetLength(0)
    $population = @()
    $baseNodes = 0..($n - 1)

    # Greedyで生成する個体数
    $greedyCount = [math]::Floor($PopSize * $GreedyRatio)

    # 1. Greedy パート
    for ($i = 0; $i -lt $greedyCount; $i++) {
        # 開始点をランダムに変える (0 ～ n-1)
        $start = Get-Random -Maximum $n
        
        # Routeを指定しなければ、自動的に 0..n-1 に対してGreedyを行う
        $route = Get-GreedyRoute -DistanceMatrix $DistMatrix -FixedStartNodeIndex $start
       
        $population += , $route
    }

    # 2. ランダム パート
    for ($i = $greedyCount; $i -lt $PopSize; $i++) {
        $route = $baseNodes | Sort-Object { Get-Random }
        $population += , $route
    }
    return $population
}

function New-NextGeneration {
    # 旧: GenerateNextPopulation
    param(
        [array]$Population,
        [double[, ]]$Dist,
        [double]$MutationRate = 0.5
    )
    
    $popSize = $Population.Count
    $next = @()
       
    for ($i = 0; $i -lt $popSize; $i++) {
        # 親選択（ランダム）
        $parent = Get-Random -InputObject $Population
        $child = $parent.Clone()
        # 突然変異実行
        $child = Invoke-MutationSwap $child
        $next += , $child
    }
    # 評価してソート
    $SortedPopulation = $next | Sort-Object { Get-RouteDistance $_ $Dist }
    return $SortedPopulation
}
    
function Invoke-GASimulation {
    # 旧: RunGALogic
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
    
    # グローバル距離行列（初期化）
    if (-not $State.ContainsKey('GlobalDist')) {
        $State.GlobalDist = New-DistanceMatrix $Places
    }
    
    # --- フェーズ: クラスタ初期化 ---
    if (-not $State.ContainsKey('ClusterData')) {
        $State.Phase = "ClusterInit"
        
        $initStart = $sw.ElapsedMilliseconds

        # ここでクラスタ生成
        $clusters = Cluster-Mesh -Places $Places
        $cd = @()
    
        for ($ci = 0; $ci -lt $clusters.Count; $ci++) {
            $inds = $clusters[$ci]
            $sub = Get-SubMatrix $State.GlobalDist $inds
    
            # Indicesを渡さず、行列だけ渡す
            $pop = New-InitialPopulation -PopSize $PopSizePerCluster `
                -DistMatrix $sub `
                -GreedyRatio 0.5

            $sortedPop = $pop | Sort-Object { Get-RouteDistance $_ $sub }
            $bestLocal = $sortedPop[0]   
            
            # 【追記】ローカルIndex(0,1,2..) を グローバルIndex(10,55,3..) に変換
            $bestGlobal = $bestLocal | ForEach-Object { $inds[$_] }
    
            $cd += , @{
                Indices         = $inds
                SubDist         = $sub
                Population      = $sortedPop 
                BestRouteLocal  = $bestLocal
                BestRouteGlobal = $bestGlobal
                BestDist        = (Get-RouteDistance $bestLocal $sub) 
            }
        }
    
        $State.ClusterData = $cd
    
        # 3. クラスタ「順序」初期化
        Write-Host "  3. Initializing Inter-Cluster Order..."
        
        # 「出口→入口」距離行列を作る
        $clusterDistMatrix = New-ClusterDistanceMatrix -ClusterData $State.ClusterData -GlobalDist $State.GlobalDist
 
        # クラスタ順序: 初期集団生成
        $orderPop = New-InitialPopulation -PopSize $PopSizeClustersOrder `
            -DistMatrix $clusterDistMatrix `
            -GreedyRatio 0.5
         
        # 順序を評価してソート
        $sortedOrderPop = $orderPop | Sort-Object { 
            Get-RouteDistance $_ $clusterDistMatrix 
        }
    
        $State.ClusterOrderPopulation = $sortedOrderPop
        $State.BestClusterOrder = $sortedOrderPop[0]

        # -----------------------------------------------------------
        # 初期状態の BestDist と BestRoute を確定させる
        # -----------------------------------------------------------
        
        # (A) ルートの結合: クラスタ順序に従って配列を繋げる
        #     先にルートを作ってしまいます。
        $fullRoute = @()
        foreach ($cIdx in $State.BestClusterOrder) {
            $fullRoute += $State.ClusterData[$cIdx].BestRouteGlobal
        }
        $State.BestRoute = $fullRoute

        # (B) 距離の計算:
        #     足し算による概算をやめ、結合後のルートに対して「真の距離」を測ります。
        #     これでループ内の計算ロジックと完全に一致します。
        $State.BestDist = Get-RouteDistance $State.BestRoute $State.GlobalDist

        # (B) ルートの結合: クラスタ順序に従って配列を繋げる
        $fullRoute = @()
        foreach ($cIdx in $State.BestClusterOrder) {
            # ClusterData配列はID順なので、順序配列のIDでアクセスして結合
            $fullRoute += $State.ClusterData[$cIdx].BestRouteGlobal
        }
        $State.BestRoute = $fullRoute

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
    
            # 次世代生成
            if ($c.Indices.count -gt 1) {
                $c.Population = New-NextGeneration -Population $c.Population -Dist $c.SubDist
            }
            $bestLocal = $c.Population[0]
            $c.BestRouteLocal = $bestLocal
            $c.BestRouteGlobal = $bestLocal | ForEach-Object { $c.Indices[$_] }
                
            # 距離測定
            $c.BestDist = Get-RouteDistance $c.BestRouteGlobal $State.GlobalDist
        }
        $t_clusterGA = $sw.ElapsedMilliseconds
    
        # 2) クラスタ間距離行列
        $State.Phase = "OrderGA"
        $clusterDist = New-ClusterDistanceMatrix $State.ClusterData $State.GlobalDist
        
        $t_matrix = $sw.ElapsedMilliseconds

        # 3) クラスタ順序 GA
        $State.ClusterOrderPopulation = New-NextGeneration -Population $State.ClusterOrderPopulation -Dist $clusterDist
        
        $t_orderGA = $sw.ElapsedMilliseconds

        # 4) 全体ルート評価
        $State.Phase = "Evaluate"
        $bestOrder = $State.ClusterOrderPopulation[0]
    
        $finalRoute = @()
        foreach ($ci in $bestOrder) {
            $finalRoute += $State.ClusterData[$ci].BestRouteGlobal
        }
    
        $finalDist = Get-RouteDistance $finalRoute $State.GlobalDist
    
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

        # ★進捗と時間をコンソール表示（50世代ごと、または最終世代）
        if ($State.Generation % 50 -eq 0 -or $State.Generation -eq $MaxGen) {
            Write-Host "Gen: $($State.Generation) | Dist: $($State.BestDist.ToString('0.00')) | Time: $($State.Performance.TotalLoopTime)ms [Cluster:$($State.Performance.ClusterGATime) Order:$($State.Performance.OrderGATime)]" -ForegroundColor Gray
        }

        # ★変更点: 条件を削除し、毎世代表示するようにしました
        Write-Host "Gen: $($State.Generation) | Dist: $($State.BestDist.ToString('0.00')) | Time: $($State.Performance.TotalLoopTime)ms" -ForegroundColor Gray
      
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
        [int] $N = 100,
        [int] $NumClusters = 50,
        [int] $PopSizePerCluster = 50,
        [int] $PopSizeClustersOrder = 100,
        [int] $MaxGen = 50
    )
    
    $Places = 1..$N | ForEach-Object { [PSCustomObject]@{ lat = Get-Random -Minimum 33.5 -Maximum 33.6; lon = Get-Random -Minimum 134.0 -Maximum 134.1 } }
    
    $state = @{
        Stop = $false
    }
    
    Invoke-GASimulation -Places $Places -State $state -NumClusters $NumClusters -PopSizePerCluster $PopSizePerCluster -PopSizeClustersOrder $PopSizeClustersOrder -MaxGen $MaxGen
    
    "Gen: $($state.Generation), BestDist: $([math]::Round($state.BestDist,3))"
}
    
# 直接実行用
if ($MyInvocation.InvocationName -eq '.\GALogic.ps1' -or $MyInvocation.InvocationName -eq 'GALogic.ps1') {
    Test-GASimulation
}
