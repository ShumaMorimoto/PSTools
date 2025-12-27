function Run-GASimulation {
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
