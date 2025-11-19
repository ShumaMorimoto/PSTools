function Optimize-Route {
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

    # 初期距離計算
    $initialGreedy = Get-TotalDistance $greedyIndividual -StartLocation $StartLocation -RouteMode $RouteMode
    $initialAverage = ($population | ForEach-Object {
        Get-TotalDistance $_ -StartLocation $StartLocation -RouteMode $RouteMode
    } | Measure-Object -Average).Average

    # GAループ
    for ($gen = 0; $gen -lt $Generations; $gen++) {
        $population = $population | Sort-Object {
            Get-TotalDistance $_ -StartLocation $StartLocation -RouteMode $RouteMode
        }

        $population = Generate-NextGeneration -population $population -StartLocation $StartLocation -RouteMode $RouteMode
    }

    $best = $population[0]
    $bestDistance = Get-TotalDistance $best -StartLocation $StartLocation -RouteMode $RouteMode
    $routeText = $prependStart ? @($StartLocation) + $best : $best

    Write-Host "[RESULT] 距離推移: $([math]::Round($initialAverage, 2)) km → $([math]::Round($initialGreedy, 2)) km → $([math]::Round($bestDistance, 2)) km"
    return $routeText
}