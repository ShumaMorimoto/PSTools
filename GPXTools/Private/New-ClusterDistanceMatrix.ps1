function New-ClusterDistanceMatrix {
    param(
        [System.Collections.ArrayList]$ClusterData,
        [double[, ]]$GlobalDist
    )
    $k = $ClusterData.Count
    $mat = [double[, ]]::new($k, $k)
    for ($i = 0; $i -lt $k; $i++) {
        # クラスタ i の出口 (Global Index)
        $exitNode = $ClusterData[$i].BestRouteGlobal[-1]

        for ($j = 0; $j -lt $k; $j++) {
            if ($i -eq $j) {
                # 自分自身への移動は無限大 (Greedyで選ばれないように)
                $mat[$i, $j] = [double]::PositiveInfinity
            }
            else {
                # クラスタ j の入口 (Global Index)
                $entryNode = $ClusterData[$j].BestRouteGlobal[0]
                # 出口 -> 入口 の距離
                $mat[$i, $j] = $GlobalDist[$exitNode, $entryNode]
            }
        }
    }
    return , $mat
}
