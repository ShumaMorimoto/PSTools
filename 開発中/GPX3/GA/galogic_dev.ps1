# GALogic.ps1
# Run 層でクラスタ化→クラスタ内世代交代→クラスタ間世代交代→結果フィードバックを行う
# Solve 関数は無し。世代交代処理は GenerateNextPopulation に限定。

# -----------------------
# 距離計算（ハーサイン）
# -----------------------
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
            if ($i -eq $j) { $dist[$i, $j] = 0 } else {
                $d = Get-Distance $Places[$i] $Places[$j]
                $dist[$i, $j] = $d; $dist[$j, $i] = $d
            }
        }
    }
    return , $dist
}

function Get-RouteDistance {
    param([int[]]$route, [double[, ]]$Dist)
    if ($route.Count -le 1) { return 0.0 }
    $s = 0.0
    for ($i = 0; $i -lt $route.Count - 1; $i++) { $s += $Dist[$route[$i], $route[$i + 1]] }
    return $s
}

# -----------------------
# 簡易クラスタ（ランダム分割）
# -----------------------
function Cluster-Random {
    param([int]$k, [array]$Places)
    $n = $Places.Count
    $perm = 0..($n - 1) | Sort-Object { Get-Random }
    $clusters = @()
    $size = [math]::Ceiling($n / $k)
    for ($i = 0; $i -lt $k; $i++) {
        $start = $i * $size; $end = [math]::Min(($i + 1) * $size - 1, $n - 1)
        if ($start -le $end) { $clusters += , ($perm[$start..$end]) }
    }
    return $clusters
}

function Get-SubMatrix {
    param($globalDist, $indices)
    $m = $indices.Count; $sub = [double[, ]]::new($m, $m)
    for ($i = 0; $i -lt $m; $i++) { for ($j = 0; $j -lt $m; $j++) { $sub[$i, $j] = $globalDist[$indices[$i], $indices[$j]] } }
    return , $sub
}

# -----------------------
# 突然変異（スワップ）
# -----------------------
function Mutate-Swap {
    param([int[]]$route)
    $len = $route.Count
    if ($len -lt 2) { return $route }
    $a = Get-Random -Minimum 0 -Maximum $len
    $b = Get-Random -Minimum 0 -Maximum $len
    if ($a -ne $b) { $t = $route[$a]; $route[$a] = $route[$b]; $route[$b] = $t }
    return $route
}

# -----------------------
# 世代交代のみ：Population と Dist を受け、次世代（ソート済）を返す
# Population: array of int[] (routes)
# Dist: 2D matrix corresponding to routes' indices
# -----------------------
function GenerateNextPopulation {
    param(
        [array]$Population,
        [double[, ]]$Dist,
        [double]$MutationRate = 0.5
    )

    $popSize = $Population.Count
    $next = @()
   
    for ($i = 0; $i -lt $popSize; $i++) {
        # 親選択（ランダム） — 単純化。拡張でトーナメント等に変更可
        $parent = Get-Random -InputObject $Population
        $child = $parent.Clone()
        #       $child = Mutate-2Opt $child
        $next += , $child
    }
    $SortedPopulation = $next | Sort-Object { Get-RouteDistance $_ $Dist }
    return $SortedPopulation
}

# -----------------------
# クラスタ間距離：各クラスタのベストルートの出口→入口を使う
# clusterData: array of hashtable { Indices, SubDist, Population, BestRouteLocal, BestRouteGlobal }
# -----------------------
function Build-ClusterDistMatrix {
    param([array]$clusterData, [double[, ]]$globalDist)
    $k = $clusterData.Count
    $mat = [double[, ]]::new($k, $k)
    for ($i = 0; $i -lt $k; $i++) {
        $exitGlobal = $clusterData[$i].BestRouteGlobal[-1]
        for ($j = 0; $j -lt $k; $j++) {
            $entryGlobal = $clusterData[$j].BestRouteGlobal[0]
            $mat[$i, $j] = $globalDist[$exitGlobal, $entryGlobal]
        }
    }
    return $mat
}

# -----------------------
# RunGALogic: 全フローを内包
# - 内部でクラスタ化を行い、各クラスタごとに Population を保持
# - 各世代：クラスタ内 GenerateNextPopulation を回し、クラスタ間 GenerateNextPopulation を回す
# - State に情報を格納して返す（停止は State.Stop）
# -----------------------
function RunGALogic {
    param(
        [array]     $Places,
        [hashtable] $State,          # 呼び出し側で作成して渡す
        [int]       $NumClusters = 5,
        [int]       $PopSizePerCluster = 50,
        [int]       $PopSizeClustersOrder = 50,
        [int]       $MaxGen = 1000
    )

    # グローバル距離行列（初期化）
    if (-not $State.ContainsKey('GlobalDist')) {
        $State.GlobalDist = New-DistanceMatrix $Places
    }

    # 初回クラスタ化と各クラスタの初期集団生成
    if (-not $State.ContainsKey('ClusterData')) {
        $clusters = Cluster-Random -k $NumClusters -Places $Places
        $cd = @()
        for ($ci = 0; $ci -lt $clusters.Count; $ci++) {
            $inds = $clusters[$ci]
            $sub = Get-SubMatrix $State.GlobalDist $inds
            # 初期 Population: ランダム順列ローカルインデックス
            $pop = @()
            for ($p = 0; $p -lt $PopSizePerCluster; $p++) {
                $pop += , ((0..($inds.Count - 1)) | Sort-Object { Get-Random })
            }
            $cd += , @{
                Indices         = $inds
                SubDist         = $sub
                Population      = $pop
                BestRouteLocal  = $null
                BestRouteGlobal = $null
                BestDist        = [double]::PositiveInfinity
            }
        }
        $State.ClusterData = $cd

        # クラスタ間順序を最適化するための Population（各個体は cluster-index の順列）
        $orderPop = @()
        for ($p = 0; $p -lt $PopSizeClustersOrder; $p++) {
            $orderPop += , ((0..($clusters.Count - 1)) | Sort-Object { Get-Random })
        }
        $State.ClusterOrderPopulation = $orderPop

        # メタ情報
        $State.Generation = 0
        $State.UpdatedAt = (Get-Date).ToUniversalTime()
        $State.BestRoute = $null
        $State.BestDist = [double]::PositiveInfinity
    }

    # 世代ループ（外部で Stop を true にすれば抜けられる）
    while (-not $State.Stop) {
        # 1) 各クラスタ内の世代交代（1 世代分）
        for ($ci = 0; $ci -lt $State.ClusterData.Count; $ci++) {
            $c = $State.ClusterData[$ci]
            $c.Population = GenerateNextPopulation -Population $c.Population -Dist $c.SubDist
            # 更新：ベスト個体（ローカルインデックス）
            $bestLocal = $c.Population[0]
            $c.BestRouteLocal = $bestLocal
            # ローカル->グローバル変換
            $c.BestRouteGlobal = $bestLocal | ForEach-Object { $c.Indices[$_] }
            $c.BestDist = Get-RouteDistance $c.BestRouteGlobal $State.GlobalDist
        }

        # 2) クラスタ間距離行列を構築（各クラスタの現在ベストルートを使用）
        $clusterDist = Build-ClusterDistMatrix $State.ClusterData $State.GlobalDist

        # 3) クラスタ間の世代交代（Cluster-order Population に対して）
        $State.ClusterOrderPopulation = GenerateNextPopulation -Population $State.ClusterOrderPopulation -Dist $clusterDist

        # 4) 現在のクラスタ順序ベストを用いて全体ルートを接続して評価
        $bestOrder = $State.ClusterOrderPopulation[0]  # 例: array of cluster indices
        # 連結
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

        # 6) 終了判定
        if ($State.Generation -ge $MaxGen) { break }
    } # end while

    # 保存して戻る（State は参照渡しなので呼び出し元にも反映される）
    return $State
}

# -----------------------
# テストラッパー
# -----------------------
function TestGAWithClusters {
    param(
        [int] $N = 100,
        [int] $NumClusters = 5,
        [int] $PopSizePerCluster = 50,
        [int] $PopSizeClustersOrder = 100,
        [int] $MaxGen = 50
    )

    $Places = 1..$N | ForEach-Object { [PSCustomObject]@{ lat = Get-Random -Minimum 0 -Maximum 90; lon = Get-Random -Minimum 0 -Maximum 180 } }

    $state = @{
        Stop = $false
    }

    RunGALogic -Places $Places -State $state -NumClusters $NumClusters -PopSizePerCluster $PopSizePerCluster -PopSizeClustersOrder $PopSizeClustersOrder -MaxGen $MaxGen

    "Gen: $($state.Generation), BestDist: $([math]::Round($state.BestDist,3))"
}

# 直接実行用
if ($MyInvocation.InvocationName -eq '.\GALogic.ps1' -or $MyInvocation.InvocationName -eq 'GALogic.ps1') {
    TestGAWithClusters
}
