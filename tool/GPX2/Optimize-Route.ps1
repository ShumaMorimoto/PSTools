function Optimize-Route4 {
    param (
        [array]$Places,
        [object]$StartLocation = $null,
        [string]$RouteMode = "Open",
        [int]$PopulationSize = 50,
        [int]$Generations = 100
    )

    # 拠点数ログ
    Write-Host "[INFO] 拠点数: $($Places.Count)"

    if ($Places.Count -eq 1) {
        Write-Host "[INFO] 拠点が1つのみのため最適化をスキップ"
        return $Places
    }

    # 始点処理
    if (-not $StartLocation) {
        $StartLocation = $Places[0]
        $targets = $Places[1..($Places.Count - 1)]
        $prependStart = $true
        Write-Host "[INFO] 始点未指定 → Places[0] を始点に設定: $($StartLocation.id)"
    } else {
        $targets = $Places
        $prependStart = $false
        Write-Host "[INFO] 始点指定あり: $($StartLocation.id)"
    }

    if ($targets.Count -eq 0) {
        Write-Host "[WARN] 訪問対象が存在しないため最適化をスキップ"
        return @($StartLocation)
    }

    # 初期個体生成
    $population = @()
    for ($i = 0; $i -lt $PopulationSize; $i++) {
        $individual = $targets | Sort-Object { Get-Random }
        $population += , $individual
    }

    for ($gen = 0; $gen -lt $Generations; $gen++) {
        # 評価
        $population = $population | Sort-Object {
            Get-TotalDistance $_ -StartLocation $StartLocation -RouteMode $RouteMode
        }

        $elite = $population[0]
        $eliteDistance = Get-TotalDistance $elite -StartLocation $StartLocation -RouteMode $RouteMode
#        Write-Host "世代 $gen - 最短距離: $([math]::Round($eliteDistance, 2)) km"
    }

    $best = $population[0]
    $bestDistance = Get-TotalDistance $best -StartLocation $StartLocation -RouteMode $RouteMode
    $routeText = $prependStart ? @($StartLocation) + $best : $best
    $routeIds = $routeText | ForEach-Object { $_.id }

    Write-Host "[RESULT] 最適距離: $([math]::Round($bestDistance, 2)) km"
    Write-Host "[RESULT] 最適経路: $($routeIds -join ' → ')"

    return $routeText
}

function Get-TotalDistance {
    param (
        [array]$Route,
        [object]$StartLocation,
        [string]$RouteMode = "Open"
    )

    $total = 0
    if ($RouteMode -eq "Open") {
        $total += Get-Distance $StartLocation $Route[0]
        for ($i = 0; $i -lt $Route.Count - 1; $i++) {
            $total += Get-Distance $Route[$i] $Route[$i + 1]
        }
    }
    elseif ($RouteMode -eq "Circle") {
        $total += Get-Distance $StartLocation $Route[0]
        for ($i = 0; $i -lt $Route.Count - 1; $i++) {
            $total += Get-Distance $Route[$i] $Route[$i + 1]
        }
        $total += Get-Distance $Route[-1] $StartLocation
    }

    return $total
}

function Get-Distance($p1, $p2) {
    $R = 6371 # 地球半径 km
    $dLat = [math]::PI / 180 * ($p2.Lat - $p1.Lat)
    $dLon = [math]::PI / 180 * ($p2.Lon - $p1.Lon)
    $lat1 = [math]::PI / 180 * $p1.Lat
    $lat2 = [math]::PI / 180 * $p2.Lat

    $a = [math]::Pow([math]::Sin($dLat / 2), 2) + [math]::Cos($lat1) * [math]::Cos($lat2) * [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

function Mutate {
    param ([array]$route)

    # 配列のシャローコピー（順序だけ変える）
    $newRoute = $route.Clone()

    # ランダムに2点を入れ替える
    do {
        $i = Get-Random -Minimum 0 -Maximum $newRoute.Count
        $j = Get-Random -Minimum 0 -Maximum $newRoute.Count
    } while ($i -eq $j)

    $temp = $newRoute[$i]
    $newRoute[$i] = $newRoute[$j]
    $newRoute[$j] = $temp

    return $newRoute
}

function Optimize-AreaRoute {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Places,
        [double]$GridSize = 0.05,
        [int]$PopulationSize = 50,
        [int]$Generations = 100
    )

    # ① グリッドクラスタリング
    $clusters = @{}
    foreach ($pt in $Places) {
        $latKey = [math]::Floor([double]$pt.lat / $GridSize)
        $lonKey = [math]::Floor([double]$pt.lon / $GridSize)
        $key = "$latKey,$lonKey"
        if (-not $clusters.ContainsKey($key)) {
            $clusters[$key] = @()
        }
        $clusters[$key] += $pt
    }

    # ② クラスタ重心算出
    $centroids = $clusters.GetEnumerator() | ForEach-Object {
        $pts = $_.Value
        $latAvg = ($pts | ForEach-Object { [double]$_.lat } | Measure-Object -Average).Average
        $lonAvg = ($pts | ForEach-Object { [double]$_.lon } | Measure-Object -Average).Average
        [PSCustomObject]@{
            Key    = $_.Key
            Lat    = $latAvg
            Lon    = $lonAvg
            Points = $pts
        }
    }

    # ③ クラスタ順序決定（Nearest Neighbor）
    $ordered = @($centroids[0])
    $remaining = $centroids[1..($centroids.Count - 1)]

    while ($remaining.Count -gt 0) {
        $last = $ordered[-1]
        $next = $remaining | Sort-Object {
            $dx = $_.Lat - $last.Lat
            $dy = $_.Lon - $last.Lon
            [math]::Sqrt($dx * $dx + $dy * $dy)
        } | Select-Object -First 1
        $ordered += $next
        $remaining = $remaining | Where-Object { $_ -ne $next }
    }

    # ④ クラスタ内ルート最適化（ベース関数使用）
    $finalRoute = @($ordered[0].Points[0])

    for ($i = 0; $i -lt $ordered.Count; $i++) {
        $cluster = $ordered[$i]
        $start = $finalRoute[-1]
        $optimized = Optimize-Route4 -Places $cluster.Points -StartLocation $start -RouteMode "Open" `
            -PopulationSize 10 -Generations 50
        $finalRoute += $optimized
    }

    return $finalRoute
}