function Optimize-Route {
    param (
        [array]$Places,
        [int]$PopulationSize = 50,
        [int]$Generations = 100,
        [ScriptBlock]$OnGeneration = $null  # ← コールバック
    )

    $population = @()
    for ($i = 0; $i -lt $PopulationSize; $i++) {
        $population += , (Get-RandomRoute $Places)
    }

    for ($gen = 0; $gen -lt $Generations; $gen++) {
        $population = $population | Sort-Object { Get-TotalDistance $_ }
        $best = $population[0]

        if (-not $best -or $best.Count -lt 2) {
            Write-Warning "⚠️ 世代 $gen で異常な個体が検出されました。"
            break
        }
        $distance = Get-TotalDistance $best

        # コールバック呼び出し
        if ($OnGeneration) {
            & $OnGeneration $gen $best $distance
        }
        else {
            Write-Host "世代 $gen - 最短距離: $([math]::Round($distance, 2)) km"
            #        Write-Host "ルート: " + ($best | ForEach-Object { $_.Name }) -join " → "
            #        Write-Host ""
        }

        $newPopulation = @()
        $newPopulation += , $best

        while ($newPopulation.Count -lt $PopulationSize) {
            $parent = $population[(Get-Random -Minimum 0 -Maximum 10)]
            $child = Mutate $parent
            if ($child.Count -eq $Places.Count) {
                $newPopulation += , $child
            }
        }
        $population = $newPopulation
    }
    return $best
}
