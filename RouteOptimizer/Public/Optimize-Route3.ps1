function Optimize-Route3 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$Places,  # ← 明示的に array 型に変更

        [double]$GridSize = 0.01  # 緯度・経度のグリッド幅（約1km）
    )

    # ① 緯度経度抽出
    $coords = $Places | ForEach-Object {
        [PSCustomObject]@{
            Element = $_
            Lat     = [double]$_.lat
            Lon     = [double]$_.lon
        }
    }

    # ② グリッドクラスタリング
    $clusters = @{}
    foreach ($pt in $coords) {
        $latKey = [math]::Floor($pt.Lat / $GridSize)
        $lonKey = [math]::Floor($pt.Lon / $GridSize)
        $key = "$latKey,$lonKey"
        if (-not $clusters.ContainsKey($key)) {
            $clusters[$key] = @()
        }
        $clusters[$key] += $pt
    }

    # ③ クラスタ重心算出
    $centroids = $clusters.GetEnumerator() | ForEach-Object {
        $pts = $_.Value
        $latAvg = ($pts.Lat | Measure-Object -Average).Average
        $lonAvg = ($pts.Lon | Measure-Object -Average).Average
        [PSCustomObject]@{
            Key    = $_.Key
            Lat    = $latAvg
            Lon    = $lonAvg
            Points = $pts
        }
    }

    # ④ クラスタ順序決定（Nearest Neighbor）
    $ordered = @($centroids[0])
    $remaining = $centroids[1..($centroids.Count - 1)]

    while ($remaining.Count -gt 0) {
        $last = $ordered[-1]
        $next = $remaining | Sort-Object {
            $dx = $_.Lat - $last.Lat
            $dy = $_.Lon - $last.Lon
            [math]::Sqrt($dx * $dx + $dy * $dy)
        } | Select-Object -First 1
        $ordered += $next
        $remaining = $remaining | Where-Object { $_ -ne $next }
    }

    # ⑤ クラスタ内ルート最適化（入口→出口）
    function Optimize-Cluster ($pts, $start = $null) {
        # 起点を決定し、並び替え対象を構築
        if (-not $start) {
            $start = $pts[0]
        }
        $targets = @($start) + $pts

        # 最適化ルート構築
        $route = @($start)
        $remaining = $targets[1..($targets.Count - 1)]

        while ($remaining.Count -gt 0) {
            $last = $route[-1]
            $next = $remaining | Sort-Object {
                $dx = $_.Lat - $last.Lat
                $dy = $_.Lon - $last.Lon
                [math]::Sqrt($dx * $dx + $dy * $dy)
            } | Select-Object -First 1
            $route += $next
            $remaining = $remaining | Where-Object { $_ -ne $next }
        }

        # 起点（先頭）を除いて返す
        return $route[1..($route.Count - 1)]
    }

    # ⑥ 全体ルート構築
    $finalRoute = @()

    for ($i = 0; $i -lt $ordered.Count; $i++) {
        $cluster = $ordered[$i]
        $start = if ($i -eq 0) { $null } else { $finalRoute[-1] }

        $optimized = Optimize-Cluster $cluster.Points $start

        $finalRoute += $optimized
    }

    # ⑦ XmlElementのみ抽出して返却
    return $finalRoute | ForEach-Object { $_.Element }
}