function Cluster-Mesh {
    param(
        [Parameter(Mandatory)]
        [array]$Places,

        [double]$MeshKm = 5.0,      # メッシュ幅（km）
        [int]$MaxGroupSize = 50     # クラスタ上限
    )

    # --- 度数換算（km → 緯度経度の度） ---
    function Get-MeshSteps {
        param([array]$Places, [double]$MeshKm)

        $latStep = $MeshKm / 111.0
        $latRef = ($Places | ForEach-Object { $_.Lat } | Measure-Object -Average).Average
        $cosLat = [math]::Cos($latRef * [math]::PI / 180.0)
        if ([math]::Abs($cosLat) -lt 1e-6) { $cosLat = 1e-6 }

        $lonStep = $MeshKm / (111.0 * $cosLat)

        return @{ LatStep = $latStep; LonStep = $lonStep }
    }

    # --- サイズ超過時の四分割（再帰） ---
    function Split-Quad {
        param([array]$Indices, [array]$Places, [int]$MaxGroupSize)

        if ($Indices.Count -le $MaxGroupSize) {
            return @([PSCustomObject]@{ Cluster = @($Indices) })
        }

        $latList = $Indices | ForEach-Object { $Places[$_].Lat }
        $lonList = $Indices | ForEach-Object { $Places[$_].Lon }

        $latMid = ($latList | Measure-Object -Average).Average
        $lonMid = ($lonList | Measure-Object -Average).Average

        $nw = @()
        $ne = @()
        $sw = @()
        $se = @()

        foreach ($i in $Indices) {
            $p = $Places[$i]
            if ($p.Lat -ge $latMid -and $p.Lon -lt $lonMid) { $nw += $i; continue }
            if ($p.Lat -ge $latMid -and $p.Lon -ge $lonMid) { $ne += $i; continue }
            if ($p.Lat -lt $latMid -and $p.Lon -lt $lonMid) { $sw += $i; continue }
            if ($p.Lat -lt $latMid -and $p.Lon -ge $lonMid) { $se += $i; continue }
        }

        $result = @()
        foreach ($sub in @($nw, $ne, $sw, $se)) {
            if ($sub.Count -gt 0) {
                $result += Split-Quad -Indices $sub -Places $Places -MaxGroupSize $MaxGroupSize
            }
        }

        return $result 
    }

    # --- メッシュ幅を計算 ---
    $steps = Get-MeshSteps -Places $Places -MeshKm $MeshKm
    $latStep = $steps.LatStep
    $lonStep = $steps.LonStep

    # --- 全体の範囲 ---
    $minLat = ($Places | ForEach-Object { $_.Lat } | Measure-Object -Minimum).Minimum
    $maxLat = ($Places | ForEach-Object { $_.Lat } | Measure-Object -Maximum).Maximum
    $minLon = ($Places | ForEach-Object { $_.Lon } | Measure-Object -Minimum).Minimum
    $maxLon = ($Places | ForEach-Object { $_.Lon } | Measure-Object -Maximum).Maximum

    $clusters = [System.Collections.ArrayList]::new()

    # --- メッシュ走査 ---
    for ($lat = $minLat; $lat -le $maxLat; $lat += $latStep) {
        for ($lon = $minLon; $lon -le $maxLon; $lon += $lonStep) {

            # このメッシュに入る index を集める
            $bucket = @()
            for ($i = 0; $i -lt $Places.Count; $i++) {
                $p = $Places[$i]
                if ($p.Lat -ge $lat -and $p.Lat -lt ($lat + $latStep) -and
                    $p.Lon -ge $lon -and $p.Lon -lt ($lon + $lonStep)) {
                    $bucket += $i
                }
            }

            if ($bucket.Count -eq 0) { continue }

            # サイズ超過なら四分割
            if ($bucket.Count -gt $MaxGroupSize) {
                $subcls = Split-Quad -Indices $bucket -Places $Places -MaxGroupSize $MaxGroupSize
                $subcls | ForEach-Object { [void]$clusters.Add(@($_.Cluster)) }
            }
            else {
                [void]$clusters.Add(@($bucket))
            }
        }
    }
    return , ([object[]]$clusters)
}