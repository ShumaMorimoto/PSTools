# GALogic.ps1

## ==============================
# GALogic.ps1
# ==============================

# 緯度経度距離計算（ハーサイン距離）
function Get-Distance($p1, $p2) {
    $R = 6371  # km
    $dLat = [math]::PI / 180 * ($p2.lat - $p1.lat)
    $dLon = [math]::PI / 180 * ($p2.lon - $p1.lon)
    $lat1 = [math]::PI / 180 * $p1.lat
    $lat2 = [math]::PI / 180 * $p2.lat

    $a = [math]::Pow([math]::Sin($dLat / 2), 2) + [math]::Cos($lat1) * [math]::Cos($lat2) * [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

# 距離行列作成
function New-DistanceMatrix {
    param($Places)

    $n = $Places.Count
    $dist = [double[, ]]::new($n, $n)

    for ($i = 0; $i -lt $n; $i++) {
        for ($j = $i; $j -lt $n; $j++) {
            if ($i -eq $j) {
                $dist[$i, $j] = 0
            }
            else {
                $d = Get-Distance $Places[$i] $Places[$j]
                $dist[$i, $j] = $d
                $dist[$j, $i] = $d  # 対称行列
            }
        }
    }
    return ,$dist
}

# ルート距離計算
function Get-RouteDistance {
    param($route, $dist)
    $sum = 0
    for ($i = 0; $i -lt $route.Count - 1; $i++) {
        $sum += $dist[$route[$i], $route[$i + 1]]
    }
    return $sum
}

# 突然変異（2-Opt）
function Mutate-2Opt {
    param($route)
    $a = Get-Random -Minimum 0 -Maximum $route.Count
    $b = Get-Random -Minimum 0 -Maximum $route.Count
    if ($a -ne $b) {
        $tmp = $route[$a]
        $route[$a] = $route[$b]
        $route[$b] = $tmp
    }
    return $route
}

# 次世代生成＋距離ソート
function GenerateNextPopulation {
    param(
        [array]$Population,
        [double[, ]]$Dist
    )

    $NextPopulation = @()
    foreach ($i in 0..($Population.Count - 1)) {
        $parent = Get-Random -InputObject $Population
        $child = $parent.Clone()
        $child = Mutate-2Opt $child
        $NextPopulation += , $child
    }

    # 距離順ソート（短い順）
    $SortedPopulation = $NextPopulation | Sort-Object { Get-RouteDistance $_ $Dist }

    return $SortedPopulation
}

# --------------------------------
# GA コアループ（RunGALogic）
# --------------------------------
function RunGALogic {
    param(
        [array]$Places,
        [hashtable]$State,
        [int]$MaxGen = 1000,
        [int]$PopSize = 100
    )

    $dist = New-DistanceMatrix $Places
    $Population = @()
    for ($i = 0; $i -lt $PopSize; $i++) { $Population += , (0..($Places.Count - 1)) }

    while (-not $State.Stop) {
        $Population = GenerateNextPopulation -Population $Population -Dist $Dist

        # ベスト選択と State 更新
        $Best = $Population[0]
        $State.BestDist = Get-RouteDistance $Best $Dist
        $State.BestRoute = $Best
        $State.Generation++
        $State.UpdatedAt = [datetime]::UtcNow

        if ($State.Generation -ge $MaxGen) { break; }
    } 
}

# --------------------------------
# テスト用ラッパー（Runspace なし）
# --------------------------------
function TestGA {
    param([array]$Places, [int]$MaxGen)

    $State = @{
        Stop       = $false
        BestDist   = [double]::PositiveInfinity
        BestRoute  = $null
        Generation = 0
        UpdatedAt  = [datetime]::MinValue
    }

    RunGALogic -Places $Places -State $State -MaxGen $MaxGen
    return $State
}

function doTest {
    # ==============================
    # テスト用データ作成
    # ==============================
    $N = 100  # 拠点数
    $Places = 1..$N | ForEach-Object {
        [PSCustomObject]@{
            lat = Get-Random -Minimum 0 -Maximum 100
            lon = Get-Random -Minimum 0 -Maximum 100
        }
    }

    # ==============================
    # TestGA 実行
    # ==============================
    $State = TestGA -Places $Places -PopulationSize 200 -MaxGen 20

    "最終世代 BestDist=$($State.BestDist) Route=$($State.BestRoute -join ',')"
}