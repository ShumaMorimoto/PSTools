# --- 距離計算（ハバーサイン公式） ---
function Get-Distance($p1, $p2) {
    $R = 6371
    $dLat = [math]::PI / 180 * ($p2.Lat - $p1.Lat)
    $dLon = [math]::PI / 180 * ($p2.Lon - $p1.Lon)
    $lat1 = [math]::PI / 180 * $p1.Lat
    $lat2 = [math]::PI / 180 * $p2.Lat

    $a = [math]::Pow([math]::Sin($dLat / 2), 2) +
         [math]::Cos($lat1) * [math]::Cos($lat2) *
         [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

# --- バケット走査＋サイズ超過時スプリット ---
function Group-Places2 {
    param (
        [Parameter(Mandatory)] [array]$Towns,
        [double]$MaxDistanceKm = 5.0,
        [int]$MaxGroupSize = 50
    )

    if ($Towns.Count -eq 0) { return @() }

    # --- サブ関数: バケット幅を距離から度に換算 ---
    function Get-BucketSteps {
        param([array]$Towns, [double]$MaxDistanceKm)
        $latStep = $MaxDistanceKm / 111.0
        $latRef = ($Towns | Measure-Object Lat -Average).Average
        $cosLat = [math]::Cos($latRef * [math]::PI / 180.0)
        if ([math]::Abs($cosLat) -lt 1e-6) { $cosLat = 1e-6 }
        $lonStep = $MaxDistanceKm / (111.0 * $cosLat)
        return @{ LatStep = $latStep; LonStep = $lonStep }
    }

    # --- サブ関数: サイズ超過時の再帰分割（必ず2要素返す） ---
    function Split-GroupRecursively {
        param(
            [array]$Towns,
            [int]$MaxGroupSize
        )

        if ($Towns.Count -le $MaxGroupSize) {
            return @($Towns, $null)   # 必ず2要素返す
        }

        $minLat = ($Towns | Measure-Object Lat -Minimum).Minimum
        $maxLat = ($Towns | Measure-Object Lat -Maximum).Maximum
        $minLon = ($Towns | Measure-Object Lon -Minimum).Minimum
        $maxLon = ($Towns | Measure-Object Lon -Maximum).Maximum

        $latMid = ($minLat + $maxLat) / 2
        $lonMid = ($minLon + $maxLon) / 2

        $nw = $Towns | Where-Object { $_.Lat -ge $latMid -and $_.Lon -lt $lonMid }
        $ne = $Towns | Where-Object { $_.Lat -ge $latMid -and $_.Lon -ge $lonMid }
        $sw = $Towns | Where-Object { $_.Lat -lt $latMid -and $_.Lon -lt $lonMid }
        $se = $Towns | Where-Object { $_.Lat -lt $latMid -and $_.Lon -ge $lonMid }

        $result = @()
        foreach ($subset in @($nw,$ne,$sw,$se)) {
            if ($subset.Count -gt 0) {
                $childGroups = Split-GroupRecursively -Towns $subset -MaxGroupSize $MaxGroupSize
                $result += $childGroups
            }
        }
        return $result
    }

    # --- 本体処理 ---
    $steps = Get-BucketSteps -Towns $Towns -MaxDistanceKm $MaxDistanceKm
    $latStep = $steps.LatStep
    $lonStep = $steps.LonStep

    $minLat = ($Towns | Measure-Object Lat -Minimum).Minimum
    $maxLat = ($Towns | Measure-Object Lat -Maximum).Maximum
    $minLon = ($Towns | Measure-Object Lon -Minimum).Minimum
    $maxLon = ($Towns | Measure-Object Lon -Maximum).Maximum

    $groups = @()
    $groupIdx = 1
    $bucketIdx = 1

    for ($lat = $minLat; $lat -le $maxLat; $lat += $latStep) {
        for ($lon = $minLon; $lon -le $maxLon; $lon += $lonStep) {
            $bucket = $Towns | Where-Object {
                $_.Lat -ge $lat -and $_.Lat -lt ($lat + $latStep) -and
                $_.Lon -ge $lon -and $_.Lon -lt ($lon + $lonStep)
            }
            if ($bucket.Count -gt 0) {
                if ($bucket.Count -gt $MaxGroupSize) {
                    $splitGroups = Split-GroupRecursively -Towns $bucket -MaxGroupSize $MaxGroupSize
                    $splitGroups = $splitGroups | Where-Object { $_ }   # $null 除外

                    foreach ($sg in $splitGroups) {
                        Write-Host "Group $($groupIdx) size: $($sg.Count)"
                        $groups += ,$sg
                        $groupIdx++
                    }
                }
                else {
                    Write-Host "Group $($groupIdx) size: $($bucket.Count)"
                    $groups += @($bucket, $null)   # 常に2要素返す
                    $groupIdx++
                }
            }
            $bucketIdx++
        }
    }

    # 最後に $null を除外
    $groups = $groups | Where-Object { $_ }

    Write-Host "Total groups formed: $($groups.Count)"
    return $groups
}