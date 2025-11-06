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
        # 中心候補を選ぶ（ここでは最初の点）
        $center = $remaining[0]

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