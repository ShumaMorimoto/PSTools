function Split-GroupRecursively {
    param([array]$Towns,[int]$MaxGroupSize)

    if ($Towns.Count -le $MaxGroupSize) {
        Write-Host "[DEBUG] Split-GroupRecursively: return group size=$($Towns.Count)"
        # PSObjectでラップ
        return @([PSCustomObject]@{ Cluster = $Towns })
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

function Group-Places {
    param([array]$Towns,[double]$MaxDistanceKm = 5.0,[int]$MaxGroupSize = 50)

    $groups = @()

    # ここでは単純に全体をSplitに渡す例
    $splitResult = Split-GroupRecursively -Towns $Towns -MaxGroupSize $MaxGroupSize

    foreach ($s in $splitResult) {
        # unwrapして「拠点配列」を取り出す
        $groups += ,$s.Cluster
    }

    Write-Host "[INFO] Total groups formed: $($groups.Count)"
    return $groups
}


