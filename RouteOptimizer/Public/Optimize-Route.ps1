function Optimize-Route {
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
    }
    else {
        $targets = $Places
        $prependStart = $false
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
    }

    $best = $population[0]
    $bestDistance = Get-TotalDistance $best -StartLocation $StartLocation -RouteMode $RouteMode
    $routeText = $prependStart ? @($StartLocation) + $best : $best
    $routeIds = $routeText | ForEach-Object { $_.id }

    Write-Host "[RESULT] 最適距離: $([math]::Round($bestDistance, 2)) km"

    return $routeText
}
