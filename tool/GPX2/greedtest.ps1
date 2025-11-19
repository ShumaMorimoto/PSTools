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


function Get-TotalDistance {
    param (
        [array]$route,
        [object]$StartLocation,
        [string]$RouteMode = "Open"
    )

    $points = $StartLocation ? @($StartLocation) + $route : $route
    $total = 0
    for ($i = 0; $i -lt $points.Count - 1; $i++) {
        $total += Get-Distance $points[$i] $points[$i + 1]
    }

    if ($RouteMode -eq "Closed") {
        $total += Get-Distance $points[-1] $points[0]
    }

    return $total
}

function Optimize-Route2 {
    param (
        [array]$Places,
        [object]$StartLocation = $null,
        [string]$RouteMode = "Open",
        [int]$PopulationSize = 50,
        [int]$Generations = 100
    )

    Write-Host "[INFO] 拠点数: $($Places.Count)"
    if ($Places.Count -eq 1) {
        Write-Host "[INFO] 拠点が1つのみのため最適化をスキップ"
        return $Places
    }

    if (-not $StartLocation) {
        $StartLocation = $Places[0]
        $targets = $Places[1..($Places.Count - 1)]
        $prependStart = $true
    } else {
        $targets = $Places
        $prependStart = $false
    }

    if ($targets.Count -eq 0) {
        Write-Host "[WARN] 訪問対象が存在しないため最適化をスキップ"
        return @($StartLocation)
    }

    # 初期個体生成（グリード法を1個体含める）
    $population = @()
    $greedyIndividual = Get-GreedyRoute -Points $targets -StartLocation $StartLocation
    $population += , $greedyIndividual

    for ($i = 1; $i -lt $PopulationSize; $i++) {
        $individual = $targets | Sort-Object { Get-Random }
        $population += , $individual
    }

    for ($gen = 0; $gen -lt $Generations; $gen++) {
        $population = $population | Sort-Object {
            Get-TotalDistance $_ -StartLocation $StartLocation -RouteMode $RouteMode
        }

        $elite = $population[0]
        $eliteDistance = Get-TotalDistance $elite -StartLocation $StartLocation -RouteMode $RouteMode
        $avgDistance = ($population | ForEach-Object {
            Get-TotalDistance $_ -StartLocation $StartLocation -RouteMode $RouteMode
        } | Measure-Object -Average).Average

        Write-Host "[GEN $gen] 最良距離: $([math]::Round($eliteDistance, 2)) km / 平均距離: $([math]::Round($avgDistance, 2)) km"

        $population = Generate-NextGeneration -population $population -StartLocation $StartLocation -RouteMode $RouteMode
    }

    $best = $population[0]
    $bestDistance = Get-TotalDistance $best -StartLocation $StartLocation -RouteMode $RouteMode
    $routeText = $prependStart ? @($StartLocation) + $best : $best

    Write-Host "[RESULT] 最適距離: $([math]::Round($bestDistance, 2)) km"
    return $routeText
}

function Generate-NextGeneration {
    param (
        [array]$population,
        [object]$StartLocation,
        [string]$RouteMode
    )

    function Get-GreedyRoute {
        param (
            [array]$Points,
            [object]$StartLocation
        )

        $remaining = $Points.Clone()
        $route = @()
        $current = $StartLocation

        while ($remaining.Count -gt 0) {
            $next = $remaining | Sort-Object {
                Get-Distance $current $_
            } | Select-Object -First 1

            $route += $next
            $remaining = $remaining | Where-Object { $_.id -ne $next.id }
            $current = $next
        }

        return $route
    }

    $nextGeneration = @()
    $elite = $population[0]
    $nextGeneration += ,$elite

    $greedyCount = 0
    $swapCount = 0

    for ($i = 1; $i -lt $population.Count; $i++) {
        $individual = $population[$i]
        $mutated = $individual.Clone()
        $count = $mutated.Count

        # Greedy変異（部分区間のみ）
        if ((Get-Random -Minimum 0.0 -Maximum 1.0) -lt 0.3) {
            $segmentSize = [math]::Min(10, $count)
            $segment = $mutated | Select-Object -First $segmentSize
            $greedy = Get-GreedyRoute -Points $segment -StartLocation $StartLocation
            $cut = Get-Random -Minimum 1 -Maximum ($greedy.Count - 1)
            $prefix = $greedy[0..$cut]
            $suffix = $mutated | Where-Object { $_.id -notin ($prefix | ForEach-Object { $_.id }) }
            $mutated = $prefix + $suffix
            $greedyCount++
        }

        # Swap変異
        if ((Get-Random -Minimum 0.0 -Maximum 1.0) -lt 0.2) {
            $i1 = Get-Random -Minimum 0 -Maximum ($count - 1)
            $i2 = Get-Random -Minimum 0 -Maximum ($count - 1)
            $temp = $mutated[$i1]
            $mutated[$i1] = $mutated[$i2]
            $mutated[$i2] = $temp
            $swapCount++
        }

        $nextGeneration += ,$mutated
    }

    Write-Host "Greedy変異: $greedyCount / Swap変異: $swapCount"
    return $nextGeneration
}