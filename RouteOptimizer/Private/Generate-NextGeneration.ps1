function Generate-NextGeneration {
    param (
        [array]$population,
        [object]$StartLocation,
        [string]$RouteMode
    )

    $nextGeneration = @()
    $elite = $population[0]
    $nextGeneration += , $elite

    $greedyCount = 0
    $swapCount = 0

    for ($i = 1; $i -lt $population.Count; $i++) {
        $individual = $population[$i]
        $mutated = $individual.Clone()
        $count = $mutated.Count

        if ($count -eq 0) {
            Write-Warning "個体 $i が空です。スキップします。"
            continue
        }

        # Greedy変異（部分区間のみ）
        if ((Get-Random -Minimum 0.0 -Maximum 1.0) -lt 0.3) {
            $segmentSize = [math]::Min(10, $count)
            $startIndex = ($count - $segmentSize) -gt 0 ? (Get-Random -Minimum 0 -Maximum ($count - $segmentSize)) : 0

            $prefix = if ($startIndex -gt 0) { $mutated[0..($startIndex - 1)] } else { @() }
            $middle = $mutated[$startIndex..($startIndex + $segmentSize - 1)]
            $suffixStart = $startIndex + $segmentSize
            $suffix = if ($suffixStart -le ($count - 1)) { $mutated[$suffixStart..($count - 1)] } else { @() }

            $greedyMiddle = Get-GreedyRoute -Points $middle -StartLocation $StartLocation
            $mutated = @($prefix) + @($greedyMiddle) + @($suffix)
            $greedyCount++
        }

        # Swap変異（安全なインデックスチェック付き）
        if ((Get-Random -Minimum 0.0 -Maximum 1.0) -lt 0.2) {
            try {
                $i1 = Get-Random -Minimum 0 -Maximum ($count - 1)
                $i2 = Get-Random -Minimum 0 -Maximum ($count - 1)

                if ($i1 -ge $count -or $i2 -ge $count) {
                    Write-Warning "Swap変異でインデックス範囲外: i=$i, i1=$i1, i2=$i2, count=$count"
                    continue
                }

                $temp = $mutated[$i1]
                $mutated[$i1] = $mutated[$i2]
                $mutated[$i2] = $temp
                $swapCount++
            }
            catch {
                Write-Warning "Swap変異で例外発生: i=$i, i1=$i1, i2=$i2, count=$count"
            }
        }

        $nextGeneration += , $mutated
    }

#    Write-Host "Greedy変異: $greedyCount / Swap変異: $swapCount"
    return $nextGeneration
}