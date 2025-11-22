function Group-Places {
    param (
        [Parameter(Mandatory)] [array]$Towns,
        [double]$MaxDistanceKm = 5.0,
        [int]$MaxGroupSize = 50
    )

    if (-not $Towns -or $Towns.Count -eq 0) {
        Write-Warning "[WARN] 入力拠点が空です"
        return @()
    }

    # --- サブ関数: バケット幅を距離から度に換算 ---
    function Get-BucketSteps {
        param([array]$Towns, [double]$MaxDistanceKm)
        $latStep = $MaxDistanceKm / 111.0
        $latRef  = ($Towns | ForEach-Object { [double]$_.Lat } | Measure-Object -Average).Average
        $cosLat  = [math]::Cos($latRef * [math]::PI / 180.0)
        if ([math]::Abs($cosLat) -lt 1e-6) { $cosLat = 1e-6 }
        $lonStep = $MaxDistanceKm / (111.0 * $cosLat)
        return @{ LatStep = $latStep; LonStep = $lonStep }
    }

    # --- サブ関数: サイズ超過時の再帰分割（必ず配列返す） ---
    function Split-GroupRecursively {
        param([array]$Towns,[int]$MaxGroupSize)

        $result = [System.Collections.ArrayList]::new()

        if ($Towns.Count -le $MaxGroupSize) {
            Write-Host "[DEBUG] Split-GroupRecursively: return group size=$($Towns.Count)"
            [void]$result.Add([object[]]$Towns)
            return ,($result.ToArray())
        }

        $minLat = ($Towns | ForEach-Object { [double]$_.Lat } | Measure-Object -Minimum).Minimum
        $maxLat = ($Towns | ForEach-Object { [double]$_.Lat } | Measure-Object -Maximum).Maximum
        $minLon = ($Towns | ForEach-Object { [double]$_.Lon } | Measure-Object -Minimum).Minimum
        $maxLon = ($Towns | ForEach-Object { [double]$_.Lon } | Measure-Object -Maximum).Maximum

        $latMid = ($minLat + $maxLat) / 2
        $lonMid = ($minLon + $maxLon) / 2

        $nw = $Towns | Where-Object { $_.Lat -ge $latMid -and $_.Lon -lt $lonMid }
        $ne = $Towns | Where-Object { $_.Lat -ge $latMid -and $_.Lon -ge $lonMid }
        $sw = $Towns | Where-Object { $_.Lat -lt $latMid -and $_.Lon -lt $lonMid }
        $se = $Towns | Where-Object { $_.Lat -lt $latMid -and $_.Lon -ge $lonMid }

        foreach ($subset in @($nw,$ne,$sw,$se)) {
            if ($subset.Count -gt 0) {
                $childGroups = Split-GroupRecursively -Towns $subset -MaxGroupSize $MaxGroupSize
                foreach ($cg in $childGroups) {
                    if ($cg -is [array]) {
                        Write-Host "[DEBUG] 子グループ追加 size=$($cg.Count)"
                        [void]$result.Add([object[]]$cg)
                    }
                }
            }
        }
        return ,($result.ToArray())
    }

    # --- 本体処理 ---
    $steps   = Get-BucketSteps -Towns $Towns -MaxDistanceKm $MaxDistanceKm
    $latStep = $steps.LatStep
    $lonStep = $steps.LonStep

    $minLat = ($Towns | ForEach-Object { [double]$_.Lat } | Measure-Object -Minimum).Minimum
    $maxLat = ($Towns | ForEach-Object { [double]$_.Lat } | Measure-Object -Maximum).Maximum
    $minLon = ($Towns | ForEach-Object { [double]$_.Lon } | Measure-Object -Minimum).Minimum
    $maxLon = ($Towns | ForEach-Object { [double]$_.Lon } | Measure-Object -Maximum).Maximum

    $groupsList = [System.Collections.ArrayList]::new()
    $groupIdx   = 1

    for ($lat = $minLat; $lat -le $maxLat; $lat += $latStep) {
        for ($lon = $minLon; $lon -le $maxLon; $lon += $lonStep) {
            $bucket = $Towns | Where-Object {
                $_.Lat -ge $lat -and $_.Lat -lt ($lat + $latStep) -and
                $_.Lon -ge $lon -and $_.Lon -lt ($lon + $lonStep)
            }

            if ($bucket.Count -gt 0) {
                if ($bucket.Count -gt $MaxGroupSize) {
                    $splitGroups = Split-GroupRecursively -Towns $bucket -MaxGroupSize $MaxGroupSize
                    foreach ($sg in $splitGroups) {
                        Write-Host "[INFO] Group $groupIdx size=$($sg.Count)"
                        [void]$groupsList.Add([object[]]$sg)
                        $groupIdx++
                    }
                } else {
                    Write-Host "[INFO] Group $groupIdx size=$($bucket.Count)"
                    [void]$groupsList.Add([object[]]$bucket)
                    $groupIdx++
                }
            }
        }
    }

    $groups = $groupsList.ToArray()
    Write-Host "[INFO] Total groups formed: $($groups.Count)"

    # --- 最終チェック ---
    $broken = $false
    foreach ($g in $groups) {
        if (-not ($g -is [array])) {
            Write-Warning "[FINAL CHECK] グループが配列でない: $($g.GetType().Name)"
            $broken = $true
        }
    }
    if (-not $broken) {
        Write-Host "[INFO] 全てのグループが配列として保持されています"
    }

    return ,([object[]]$groups)
}