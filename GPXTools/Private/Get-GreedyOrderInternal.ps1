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
