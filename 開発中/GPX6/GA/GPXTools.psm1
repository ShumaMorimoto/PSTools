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
        [double[, ]]$Dist,
        [int]$K = 3
    )

    $candidates = 1..$K | ForEach-Object {
        Get-Random -InputObject $Population
    }
    return ($candidates | Sort-Object { Get-RouteDistance $_ $Dist })[0]
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
    return , ([object[]]$clusters)
}
function New-NextGeneration {
    param(
        [array]$Population,
        [double[, ]]$Dist,
        [double]$MutationRate = 0.3,
        [double]$EliteReserveRate = 0.1,
        [double]$GreedyMutationRate = 0.1
    )

    # ★ 拠点が 1 個なら GA は無意味 → スキップ
    if ($Population.Count -eq 0 -or $Population[0].Count -le 1) {
        return $Population
    }

    $popSize = $Population.Count

    # 1. 評価してソート
    $sortedCurrent = $Population | Sort-Object { Get-RouteDistance $_ $Dist }

    # 2. エリート数
    $eliteCount = [math]::Floor($popSize * $EliteReserveRate)
    if ($eliteCount -lt 1) { $eliteCount = 1 }

    # 3. エリートコピー
    $next = @()
    $elites = $sortedCurrent[0..($eliteCount - 1)]
    foreach ($e in $elites) {
        $next += , ($e.Clone())
    }

    # 3.5 エリート改善（部分 Greedy）
    for ($idx = 1; $idx -lt $eliteCount; $idx++) {
        $route = $next[$idx]

        ($i, $j) = Get-Random -Minimum 0 -Maximum $route.Count | Sort-Object

        if ($i -lt $j) {
            $next[$idx] = Get-GreedyRoute `
                -DistanceMatrix $Dist `
                -Route $route `
                -StartPos $i `
                -EndPos $j
        }
    }

    # 4. 残りを生成
    while ($next.Count -lt $popSize) {
        # 親選択
        $parentA = Select-Tournament $Population $Dist
        $parentB = Select-Tournament $Population $Dist

        # 交叉
        $child = Invoke-CrossoverOX $parentA $parentB

        # Swap Mutation
        if ((Get-Random) -lt $MutationRate) {
            $child = Invoke-MutationSwap $child
        }

        # Greedy Mutation（局所改善）
        if ((Get-Random) -lt $GreedyMutationRate) {
            ($i, $j) = Get-Random -Minimum 0 -Maximum $child.Count | Sort-Object
            if ($i -lt $j) {
                $child = Get-GreedyRoute `
                    -DistanceMatrix $Dist `
                    -Route $child `
                    -StartPos $i `
                    -EndPos $j
            }
        }
        $next += , $child
    }
    # 5. 次世代をソートして返す
    return ($next | Sort-Object { Get-RouteDistance $_ $Dist })
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
    
