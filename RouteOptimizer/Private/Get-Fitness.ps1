function Get-Fitness($route) {
    $distance = Get-TotalDistance $route

    # 前半に訪問する地点の数（＝ルートの半分）
    $half = [math]::Floor($route.Count / 2)

    # 前半にいる地点の「順序スコア」を加算（早いほど良い）
    $orderScore = 0
    for ($i = 0; $i -lt $route.Count; $i++) {
        $weight = ($route.Count - $i)  # 早いほど重みが大きい
        $orderScore += $weight
    }

    # 総合スコア：距離 - 順序スコア × 重み
    return $distance - ($orderScore * 0.01)  # 重みは調整可能
}
