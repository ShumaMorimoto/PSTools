function Invoke-DBSCAN {
    param (
        [array]$Points,         # 各点は @{id=..., lat=..., lon=...}
        [double]$Eps = 0.01,    # 近傍距離（緯度・経度単位）
        [int]$MinPts = 3        # 最小近傍点数
    )

    $visited = @{}
    $clusters = @()
    $noise = @()

    function Get-Distance($a, $b) {
        $dx = [double]$a.lat - [double]$b.lat
        $dy = [double]$a.lon - [double]$b.lon
        return [math]::Sqrt($dx * $dx + $dy * $dy)
    }

    function RegionQuery($pt) {
        return $Points | Where-Object { Get-Distance $_ $pt -le $Eps }
    }

    function ExpandCluster($pt, $neighbors, $cluster) {
        $cluster += $pt
        foreach ($n in $neighbors) {
            if (-not $visited[$n.id]) {
                $visited[$n.id] = $true
                $nNeighbors = RegionQuery $n
                if ($nNeighbors.Count -ge $MinPts) {
                    $neighbors += $nNeighbors | Where-Object { $cluster -notcontains $_ }
                }
            }
            if ($cluster -notcontains $n) {
                $cluster += $n
            }
        }
        return $cluster
    }

    foreach ($pt in $Points) {
        if ($visited[$pt.id]) { continue }
        $visited[$pt.id] = $true
        $neighbors = RegionQuery $pt
        if ($neighbors.Count -lt $MinPts) {
            $noise += $pt
        } else {
            $cluster = @()
            $cluster = ExpandCluster $pt $neighbors $cluster
            $clusters += ,$cluster
        }
    }

    return [PSCustomObject]@{
        Clusters = $clusters
        Noise    = $noise
    }
}

function Invoke-KMeans {
    param (
        [array]$Points,       # @{id=..., lat=..., lon=...}
        [int]$K = 5,
        [int]$MaxIter = 100
    )

    function Get-Distance($a, $b) {
        $dx = [double]$a.lat - [double]$b.lat
        $dy = [double]$a.lon - [double]$b.lon
        return [math]::Sqrt($dx * $dx + $dy * $dy)
    }

    # 初期中心をランダムに選ぶ
    $centroids = $Points | Get-Random -Count $K
    $clusters = @{}

    for ($iter = 0; $iter -lt $MaxIter; $iter++) {
        $clusters.Clear()
        foreach ($i in 0..($K - 1)) { $clusters[$i] = @() }

        # 各点を最近傍の中心に割り当て
        foreach ($pt in $Points) {
            $nearest = ($centroids | ForEach-Object {
                @{Index = $_; Dist = Get-Distance $pt $_}
            }) | Sort-Object Dist | Select-Object -First 1
            $idx = $centroids.IndexOf($nearest.Index)
            $clusters[$idx] += $pt
        }

        # 新しい中心を計算
        $newCentroids = @()
        foreach ($i in 0..($K - 1)) {
            $group = $clusters[$i]
            if ($group.Count -eq 0) {
                $newCentroids += $centroids[$i]
                continue
            }
            $latAvg = ($group | ForEach-Object { $_.lat } | Measure-Object -Average).Average
            $lonAvg = ($group | ForEach-Object { $_.lon } | Measure-Object -Average).Average
            $newCentroids += @{id="C$i"; lat=$latAvg; lon=$lonAvg}
        }

        # 収束判定（中心が変わらなければ終了）
        if ($newCentroids -join ',' -eq $centroids -join ',') { break }
        $centroids = $newCentroids
    }

    return $clusters
}

function Group-ByCenterProximity {
    param (
        [array]$Places,
        [int]$MaxPerGroup = 10
    )

    function Get-Distance($a, $b) {
        $dx = [double]$a.lat - [double]$b.lat
        $dy = [double]$a.lon - [double]$b.lon
        return [math]::Sqrt($dx * $dx + $dy * $dy)
    }

    $remaining = $Places.Clone()
    $groups = @()

    while ($remaining.Count -gt 0) {
        # 各点の近傍距離合計を計算
        $densityScores = $remaining | ForEach-Object {
            $pt = $_
            $sum = ($remaining | Where-Object { $_ -ne $pt } | ForEach-Object {
                Get-Distance $_ $pt
            }) | Measure-Object -Sum
            [PSCustomObject]@{ Point = $pt; Score = $sum.Sum }
        }

        # 最も密な点（距離合計が最小）を中心に選ぶ
        $center = ($densityScores | Sort-Object Score)[0].Point

        # 中心から近い順に最大N件を取得
        $group = $remaining | Sort-Object { Get-Distance $_ $center } | Select-Object -First $MaxPerGroup

        # グループを保存
        $groups += ,$group

        # 使用済みを除外
        $usedIds = $group | ForEach-Object { $_.id }
        $remaining = $remaining | Where-Object { $usedIds -notcontains $_.id }
    }

    return $groups
}

function Group-ByRadiusAndCount {
    param (
        [array]$Places,
        [int]$MaxPerGroup = 10,
        [double]$MaxRadius = 0.02  # 緯度・経度で約2km程度
    )

    function Get-Distance($a, $b) {
        $dx = [double]$a.lat - [double]$b.lat
        $dy = [double]$a.lon - [double]$b.lon
        return [math]::Sqrt($dx * $dx + $dy * $dy)
    }

    $remaining = $Places.Clone()
    $groups = @()

    while ($remaining.Count -gt 0) {
        $center = $remaining[0]
        $group = @($center)
        $remaining = $remaining | Where-Object { $_ -ne $center }

        while ($group.Count -lt $MaxPerGroup -and $remaining.Count -gt 0) {
            $next = $remaining | Sort-Object { Get-Distance $_ $center } | Where-Object {
                Get-Distance $_ $center -le $MaxRadius
            } | Select-Object -First 1

            if (-not $next) { break }

            $group += $next
            $remaining = $remaining | Where-Object { $_ -ne $next }

            # 重心更新（任意）
            $latAvg = ($group | ForEach-Object { $_.lat } | Measure-Object -Average).Average
            $lonAvg = ($group | ForEach-Object { $_.lon } | Measure-Object -Average).Average
            $center = @{ lat = $latAvg; lon = $lonAvg }
        }

        $groups += ,$group
    }

    return $groups
}

function Show-Groups {
    param (
        [Parameter(Mandatory)]
        [array]$Clusters  # 各クラスタは @{id=..., lat=..., lon=...} の配列
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    $form = New-Object Windows.Forms.Form
    $form.Text = "クラスタと重心円のプロット"
    $form.Width = 800
    $form.Height = 600

    $chart = New-Object Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = 780
    $chart.Height = 560
    $chart.Left = 10
    $chart.Top = 10

    $chartArea = New-Object Windows.Forms.DataVisualization.Charting.ChartArea
    $chartArea.AxisX.Title = "Longitude"
    $chartArea.AxisY.Title = "Latitude"
    $chartArea.AxisY.IsStartedFromZero = $false
    $chartArea.AxisY.Minimum = [double]::NaN
    $chartArea.AxisY.Maximum = [double]::NaN
    $chartArea.AxisY.IntervalAutoMode = 'VariableCount'
    $chartArea.AxisX.Minimum = [double]::NaN
    $chartArea.AxisX.Maximum = [double]::NaN
    $chartArea.AxisX.IntervalAutoMode = 'VariableCount'
    $chart.ChartAreas.Add($chartArea)

    $colors = @("Red", "Blue", "Green", "Orange", "Purple", "Brown", "Teal", "DarkCyan", "DarkMagenta", "DarkGoldenrod")

    for ($i = 0; $i -lt $Clusters.Count; $i++) {
        $cluster = $Clusters[$i]
        $series = New-Object Windows.Forms.DataVisualization.Charting.Series "Cluster$i"
        $series.ChartType = 'Point'
        $series.Color = $colors[$i % $colors.Count]
        $series.MarkerSize = 8
        $series.IsValueShownAsLabel = $false

        $lats = @()
        $lons = @()

        foreach ($pt in $cluster) {
            $lats += [double]$pt.lat
            $lons += [double]$pt.lon
            $series.Points.AddXY($pt.lon, $pt.lat) | Out-Null
        }

        # 重心計算
        $latAvg = ($lats | Measure-Object -Average).Average
        $lonAvg = ($lons | Measure-Object -Average).Average

        # 最大距離（ユークリッド距離）
        $maxDist = 0.0
        for ($j = 0; $j -lt $lats.Count; $j++) {
            $dx = $lats[$j] - $latAvg
            $dy = $lons[$j] - $lonAvg
            $dist = [math]::Sqrt($dx * $dx + $dy * $dy)
            if ($dist -gt $maxDist) { $maxDist = $dist }
        }

        # 円描画（Seriesで近似）
        $circle = New-Object Windows.Forms.DataVisualization.Charting.Series "Circle$i"
        $circle.ChartType = 'Spline'
        $circle.Color = $colors[$i % $colors.Count]
        $circle.BorderDashStyle = 'Dash'
        $circle.BorderWidth = 1

        for ($theta = 0; $theta -le 360; $theta += 5) {
            $rad = $theta * [math]::PI / 180
            $x = $lonAvg + $maxDist * [math]::Cos($rad)
            $y = $latAvg + $maxDist * [math]::Sin($rad)
            $circle.Points.AddXY($x, $y) | Out-Null
        }

        $chart.Series.Add($series)
        $chart.Series.Add($circle)
    }

    $form.Controls.Add($chart)
    $form.ShowDialog()
}

function Get-DistanceKm {
    param($lat1, $lon1, $lat2, $lon2)
    $R = 6371
    $dLat = [math]::PI * ($lat2 - $lat1) / 180
    $dLon = [math]::PI * ($lon2 - $lon1) / 180

    $a = [math]::Pow([math]::Sin($dLat / 2), 2) +
         [math]::Cos([math]::PI * $lat1 / 180) *
         [math]::Cos([math]::PI * $lat2 / 180) *
         [math]::Pow([math]::Sin($dLon / 2), 2)

    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

function Group-Towns {
    param (
        [Parameter(Mandatory)] [array]$Towns,
        [double]$MaxDistanceKm = 5.0,
        [int]$MaxGroupSize = 30
    )

    $unassigned = $Towns.Clone()
    $grouped = @()
    $groupIndex = 1

    while ($unassigned.Count -gt 0) {
        $seed = $unassigned[0]
        $group = @($seed)
        $unassigned = $unassigned | Where-Object { $_ -ne $seed }

        foreach ($candidate in $unassigned) {
            if ($group.Count -ge $MaxGroupSize) {
                break
            }

            $dist = Get-Distance $seed $candidate

            if ($dist -le $MaxDistanceKm) {
                $group += $candidate
            } else {
            }
        }

        Write-Host "Group $groupIndex size: $($group.Count)"
        $grouped += ,$group
        $unassigned = $unassigned | Where-Object { $group -notcontains $_ }
        $groupIndex++
    }

    Write-Host "Total groups formed: $($grouped.Count)"
    return $grouped
}