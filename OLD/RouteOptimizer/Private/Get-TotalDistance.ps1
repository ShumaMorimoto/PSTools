function Get-TotalDistance {
    param (
        [array]$Route,
        [object]$StartLocation,
        [string]$RouteMode = "Open"
    )

    $total = 0
    if ($RouteMode -eq "Open") {
        # 始点固定 → 始点→1番目→2番目…と足す
        $total += Get-Distance $StartLocation $Route[0]
        for ($i = 0; $i -lt $Route.Count - 1; $i++) {
            $total += Get-Distance $Route[$i] $Route[$i + 1]
        }
    }
    elseif ($RouteMode -eq "Circle") {
        # 始点固定＋閉路 → 始点→…→最終点→始点
        $total += Get-Distance $StartLocation $Route[0]
        for ($i = 0; $i -lt $Route.Count - 1; $i++) {
            $total += Get-Distance $Route[$i] $Route[$i + 1]
        }
        $total += Get-Distance $Route[-1] $StartLocation
    }
    elseif ($RouteMode -eq "Free") {
        # 始点フリー → 始点を無視して拠点一覧の1番目から順に足す
        for ($i = 0; $i -lt $Route.Count - 1; $i++) {
            $total += Get-Distance $Route[$i] $Route[$i + 1]
        }
    }

    return $total
}