function Cluster-Mesh {
    param(
        [Parameter(Mandatory)]
        [array]$Places,    # lat,lonの属性を持ったPSOの配列
        [double]$MeshKm = 5.0,      # メッシュ幅（km）
        [int]$MaxGroupSize = 50     # クラスタ上限
    )

    # ヘルパー関数: 緯度経度からメッシュキー生成（おおよそのkmベースでグリッド化）
    function Get-MeshKey {
        param(
            [double]$lat,
            [double]$lon,
            [double]$meshSizeKm
        )
        # 緯度1度の距離 ≈ 111 km
        $deltaLat = $meshSizeKm / 111.0
        # 経度1度の距離 ≈ 111 * cos(lat) km（平均的な緯度で近似）
        $avgLat = 35.0  # 日本近辺の平均緯度を仮定（必要に応じて調整）
        $deltaLon = $meshSizeKm / (111.0 * [Math]::Cos($avgLat * [Math]::PI / 180.0))

        $keyLat = [Math]::Floor($lat / $deltaLat)
        $keyLon = [Math]::Floor($lon / $deltaLon)
        return "$keyLat,$keyLon"
    }

    # インデックス付きでPlacesを処理
    $indexedPlaces = 0..($Places.Length - 1) | ForEach-Object {
        [PSCustomObject]@{
            Index = $_
            Lat = $Places[$_].lat
            Lon = $Places[$_].lon
        }
    }

    # メッシュキーでグループ化
    $meshGroups = @{}
    foreach ($place in $indexedPlaces) {
        $key = Get-MeshKey -lat $place.Lat -lon $place.Lon -meshSizeKm $MeshKm
        if (-not $meshGroups.ContainsKey($key)) {
            $meshGroups[$key] = @()
        }
        $meshGroups[$key] += $place.Index
    }

    # 各メッシュグループをMaxGroupSize以内に分割
    $result = @()
    foreach ($group in $meshGroups.Values) {
        for ($i = 0; $i -lt $group.Length; $i += $MaxGroupSize) {
            $subGroup = $group[$i..([Math]::Min($i + $MaxGroupSize - 1, $group.Length - 1))]
            $result += ,$subGroup  # 配列の配列として追加
        }
    }

    return $result
}

function Cluster-KMeans {
    param(
        [Parameter(Mandatory)]
        [array]$Places,    # lat,lonの属性を持ったPSOの配列
        [int]$NumClusters = 10,     # クラスタ数（自動調整可能）
        [int]$MaxGroupSize = 50,    # クラスタ上限（これを超えないようNumClustersを調整）
        [int]$MaxIterations = 100   # 最大イテレーション
    )

    # Haversine距離計算ヘルパー（km）
    function Get-Distance {
        param([double]$lat1, [double]$lon1, [double]$lat2, [double]$lon2)
        $R = 6371.0  # 地球半径 km
        $dLat = ($lat2 - $lat1) * [Math]::PI / 180
        $dLon = ($lon2 - $lon1) * [Math]::PI / 180
        $a = [Math]::Sin($dLat / 2) * [Math]::Sin($dLat / 2) + [Math]::Cos($lat1 * [Math]::PI / 180) * [Math]::Cos($lat2 * [Math]::PI / 180) * [Math]::Sin($dLon / 2) * [Math]::Sin($dLon / 2)
        $c = 2 * [Math]::Atan2([Math]::Sqrt($a), [Math]::Sqrt(1 - $a))
        return $R * $c
    }

    # インデックス付きPlaces
    $indexedPlaces = 0..($Places.Length - 1) | ForEach-Object {
        [PSCustomObject]@{
            Index = $_
            Lat = $Places[$_].lat
            Lon = $Places[$_].lon
        }
    }

    # NumClustersをMaxGroupSizeに基づいて最小限に調整（大まか）
    $minClusters = [Math]::Ceiling($Places.Length / $MaxGroupSize)
    if ($NumClusters -lt $minClusters) { $NumClusters = $minClusters }

    # 初期中心点をランダム選択
    $centers = @()
    $randomIndices = Get-Random -InputObject (0..($Places.Length - 1)) -Count $NumClusters
    foreach ($idx in $randomIndices) {
        $centers += [PSCustomObject]@{ Lat = $Places[$idx].lat; Lon = $Places[$idx].lon }
    }

    # イテレーション
    for ($iter = 0; $iter -lt $MaxIterations; $iter++) {
        # 各ポイントを最近傍中心に割り当て
        $clusters = @{}  # クラスタインデックス -> ポイントインデックスの配列
        for ($c = 0; $c -lt $NumClusters; $c++) { $clusters[$c] = @() }

        foreach ($place in $indexedPlaces) {
            $minDist = [double]::MaxValue
            $closest = -1
            for ($c = 0; $c -lt $NumClusters; $c++) {
                $dist = Get-Distance $place.Lat $place.Lon $centers[$c].Lat $centers[$c].Lon
                if ($dist -lt $minDist) { $minDist = $dist; $closest = $c }
            }
            $clusters[$closest] += $place.Index
        }

        # 中心点を更新
        $changed = $false
        for ($c = 0; $c -lt $NumClusters; $c++) {
            if ($clusters[$c].Count -eq 0) { continue }  # 空クラスタ回避
            $sumLat = 0; $sumLon = 0
            foreach ($idx in $clusters[$c]) {
                $sumLat += $Places[$idx].lat
                $sumLon += $Places[$idx].lon
            }
            $newLat = $sumLat / $clusters[$c].Count
            $newLon = $sumLon / $clusters[$c].Count
            if ([Math]::Abs($newLat - $centers[$c].Lat) -gt 1e-6 -or [Math]::Abs($newLon - $centers[$c].Lon) -gt 1e-6) {
                $changed = $true
            }
            $centers[$c].Lat = $newLat
            $centers[$c].Lon = $newLon
        }

        if (-not $changed) { break }  # 収束したら終了
    }

    # 各クラスタをMaxGroupSize以内に分割（大きい場合）
    $result = @()
    foreach ($group in $clusters.Values) {
        for ($i = 0; $i -lt $group.Length; $i += $MaxGroupSize) {
            $subGroup = $group[$i..([Math]::Min($i + $MaxGroupSize - 1, $group.Length - 1))]
            $result += ,$subGroup
        }
    }

    return $result
}