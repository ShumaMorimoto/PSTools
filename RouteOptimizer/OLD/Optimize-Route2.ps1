function Optimize-Route2 {
    param (
        [array]$Places,
        [int]$PopulationSize = 50,
        [int]$Generations = 100,
        [ScriptBlock]$OnGeneration = $null,
        [ScriptBlock]$FitnessFunction = $null  # ← 評価関数を追加
    )

    # デフォルト評価関数（総距離）
    if (-not $FitnessFunction) {
        $FitnessFunction = { param($route) Get-TotalDistance $route }
    }

    $population = @()
    for ($i = 0; $i -lt $PopulationSize; $i++) {
        $population += , (Get-RandomRoute $Places)
    }

    for ($gen = 0; $gen -lt $Generations; $gen++) {
        $population = $population | Sort-Object { & $FitnessFunction $_ }
        $best = $population[0]
        $distance = Get-TotalDistance $best

        if ($OnGeneration) {
            & $OnGeneration $gen $best $distance
        }
        else {
            Write-Host "世代 $gen - 最短距離: $([math]::Round($distance, 2)) km"
        }

        $newPopulation = @()
        $newPopulation += , $best  # エリート保存

        while ($newPopulation.Count -lt $PopulationSize) {
            $parent1 = Select-Parent $population
            $parent2 = Select-Parent $population

            $child = Crossover $parent1 $parent2
            $child = Mutate $child

            if ($child.Count -eq $Places.Count) {
                $newPopulation += , $child
            }
        }
        $population = $newPopulation
    }
    return $best
}
