function Get-GreedyRoute {
    param(
        [Parameter(Mandatory)]
        [double[, ]]$DistanceMatrix,

        [int[]]$Route = $null,
        
        # 部分Greedy用のパラメータ
        [Nullable[int]]$StartPos = $null,
        [Nullable[int]]$EndPos = $null,

        # 全体Greedyの開始ノードを指定するためのパラメータ（今回追加）
        # $Route内のインデックスを指定する (0 ～ Route.Count-1)
        [int]$FixedStartNodeIndex = 0 
    )

    # 内部関数: インデックス配列に対するGreedy順序生成
    function Get-GreedyOrderInternal {
        param(
            [double[, ]]$DistanceMatrix,
            [int[]]$Nodes,
            [int]$StartIndex = 0
        )
        $n = $Nodes.Count
        $visited = [bool[]]::new($n)
        $visited[$StartIndex] = $true
        $currentNode = $Nodes[$StartIndex]

        $result = New-Object System.Collections.Generic.List[int]
        $result.Add($currentNode)

        for ($step = 1; $step -lt $n; $step++) {
            $nearest = -1
            $minDist = [double]::PositiveInfinity

            for ($i = 0; $i -lt $n; $i++) {
                if (-not $visited[$i]) {
                    $candidate = $Nodes[$i]
                    $d = $DistanceMatrix[$currentNode, $candidate]
                    if ($d -lt $minDist) {
                        $minDist = $d
                        $nearest = $i
                    }
                }
            }
            $visited[$nearest] = $true
            $currentNode = $Nodes[$nearest]
            $result.Add($currentNode)
        }
        return $result.ToArray()
    }

    # --- 1. Route が null → 全体 Greedy ---
    # $DistanceMatrix の次元数ぶんのノード (0..N-1) を対象にする
    if ($Route -eq $null) {
        $n = $DistanceMatrix.GetLength(0)
        $nodes = 0..($n - 1)
        # 渡された FixedStartNodeIndex を開始点として利用
        return Get-GreedyOrderInternal $DistanceMatrix $nodes $FixedStartNodeIndex
    }

    # --- 2. Route 全体 Greedy ---
    # 既存のノードリストを並べ替える
    if ($StartPos -eq $null -and $EndPos -eq $null) {
        # 渡された FixedStartNodeIndex を開始点として利用
        return Get-GreedyOrderInternal $DistanceMatrix $Route $FixedStartNodeIndex
    }

    # --- 3. 区間 Greedy (部分最適化) ---
    # ※区間Greedyの場合は、区間の先頭($segment[0])から始めるのが基本ロジックのため
    #   FixedStartNodeIndex は無視して 0 固定とします。
    if ($StartPos -ne $null -and $EndPos -ne $null) {
        if ($StartPos -lt 0 -or $EndPos -ge $Route.Count -or $StartPos -ge $EndPos) {
            throw "StartPos / EndPos が不正です。"
        }
        $segment = $Route[$StartPos..$EndPos]
        $newSegment = Get-GreedyOrderInternal $DistanceMatrix $segment 0

        $newRoute = @()
        if ($StartPos -gt 0) { $newRoute += $Route[0..($StartPos - 1)] }
        $newRoute += $newSegment
        if ($EndPos -lt $Route.Count - 1) { $newRoute += $Route[($EndPos + 1)..($Route.Count - 1)] }

        return $newRoute
    }

    throw "パラメータの組み合わせが不正です。"
}
