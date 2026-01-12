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

    # --- サブ関数: サイズ超過時の再帰分割（PSObjectでラップして返す） ---
    function Split-GroupRecursively {
        param([array]$Towns,[int]$MaxGroupSize)

        if ($Towns.Count -le $MaxGroupSize) {
            Write-Host "[DEBUG] Split-GroupRecursively: return group size=$($Towns.Count)"
            return @([PSCustomObject]@{ Cluster = @($Towns) })
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

        $result = @()
        foreach ($subset in @($nw,$ne,$sw,$se)) {
            if ($subset.Count -gt 0) {
                $result += Split-GroupRecursively -Towns $subset -MaxGroupSize $MaxGroupSize
            }
        }
        return $result
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
                        Write-Host "[INFO] Group $groupIdx size=$($sg.Cluster.Count)"
                        [void]$groupsList.Add(@($sg.Cluster))   # ← 必ず配列として追加
                        $groupIdx++
                    }
                } else {
                    Write-Host "[INFO] Group $groupIdx size=$($bucket.Count)"
                    [void]$groupsList.Add(@($bucket))          # ← 1要素でも配列として追加
                    $groupIdx++
                }
            }
        }
    }

    Write-Host "[INFO] Total groups formed: $($groupsList.Count)"

    # --- 最終チェック ---
    $broken = $false
    foreach ($g in $groupsList) {
        if (-not ($g -is [array])) {
            Write-Warning "[FINAL CHECK] グループが配列でない: $($g.GetType().Name)"
            $broken = $true
        }
    }
    if (-not $broken) {
        Write-Host "[INFO] 全てのグループが配列として保持されています"
    }

    # 最後に配列化して返す
    return ,([object[]]$groupsList)
}