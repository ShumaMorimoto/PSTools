function Mutate {
    param ([array]$route)

    # 配列のシャローコピー（順序だけ変える）
    $newRoute = $route.Clone()

    # ランダムに2点を入れ替える
    do {
        $i = Get-Random -Minimum 0 -Maximum $newRoute.Count
        $j = Get-Random -Minimum 0 -Maximum $newRoute.Count
    } while ($i -eq $j)

    $temp = $newRoute[$i]
    $newRoute[$i] = $newRoute[$j]
    $newRoute[$j] = $temp

    return $newRoute
}