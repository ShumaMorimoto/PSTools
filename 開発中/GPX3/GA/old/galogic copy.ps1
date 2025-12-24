# GALogic.ps1

function Get-Distance($p1, $p2) {
    $R = 6371 # 地球半径 km
    $dLat = [math]::PI / 180 * ($p2.Lat - $p1.Lat)
    $dLon = [math]::PI / 180 * ($p2.Lon - $p1.Lon)
    $lat1 = [math]::PI / 180 * $p1.Lat
    $lat2 = [math]::PI / 180 * $p2.Lat

    $a = [math]::Pow([math]::Sin($dLat / 2), 2) + [math]::Cos($lat1) * [math]::Cos($lat2) * [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

function New-DistanceMatrix {
    param($Places)
    $n = $Places.Count
    $dist = [double[, ]]::new($n, $n)

    for ($i = 0; $i -lt $n; $i++) {
        for ($j = $i; $j -lt $n; $j++) {
            if ($i -eq $j) {
                $dist[$i, $j] = 0
            }
            else {
                $d = Get-Distance $Places[$i] $Places[$j]
                $dist[$i, $j] = $d
                $dist[$j, $i] = $d  # 対称
            }
        }
    }
    return , $dist
}


function Get-RouteDistance {
    param($route, $dist)
    $sum = 0
    for ($i = 0; $i -lt $route.Count - 1; $i++) {
        $sum += $dist[$route[$i], $route[$i + 1]]
    }
    return $sum
}

function Mutate-2Opt {
    param($route)
    $a = Get-Random -Minimum 0 -Maximum $route.Count
    $b = Get-Random -Minimum 0 -Maximum $route.Count
    if ($a -ne $b) {
        $tmp = $route[$a]
        $route[$a] = $route[$b]
        $route[$b] = $tmp
    }
    return $route
}

function RunGA {
    param($Places, $State)

    # 距離行列と初期ルート
    $dist = New-DistanceMatrix $Places
    $route = 0..($Places.Count - 1)

    while (-not $State.Stop) {
        $candidate = Mutate-2Opt $route.Clone()
        $distCandidate = Get-RouteDistance $candidate $dist

        if ($distCandidate -lt $State.BestDist) {
            $State.BestDist = $distCandidate
            $State.BestRoute = $candidate
            $State.UpdatedAt = [datetime]::UtcNow
        }

        $State.Generation++
        Start-Sleep -Milliseconds 200
    }
}

# Runspace なしでロジック確認用
function TestGA {
    param($Places)

    $State = @{
        Stop       = $false
        BestDist   = [double]::PositiveInfinity
        BestRoute  = $null
        Generation = 0
        UpdatedAt  = [datetime]::MinValue
    }

    # GAループ（最大10世代で停止）
    $maxGen = 100
    $dist = New-DistanceMatrix $Places
    $route = 0..($Places.Count - 1)
    while ($State.Generation -lt $maxGen) {
        $candidate = Mutate-2Opt $route.Clone()
        $distCandidate = Get-RouteDistance $candidate $dist

        if ($distCandidate -lt $State.BestDist) {
            $State.BestDist = $distCandidate
            $State.BestRoute = $candidate
            $State.UpdatedAt = [datetime]::UtcNow
        }

        $State.Generation++
        "Gen=$($State.Generation) BestDist=$($State.BestDist) Route=$($State.BestRoute -join ',')"

    }

    return $State
}
