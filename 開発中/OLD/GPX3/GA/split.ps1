function Split-Recursive {
    param(
        [array]$Indices,
        [int]$MaxSize = 3
    )

    if ($Indices.Count -le $MaxSize) {
        return @([PSCustomObject]@{Cluster = @($Indices) })
    }

    $mid = [math]::Floor($Indices.Count / 2)

    $left = $Indices[0..($mid - 1)]
    $right = $Indices[$mid..($Indices.Count - 1)]


    $result = @()
    $result +=  Split-Recursive -Indices $left -MaxSize $MaxSize
    $result +=  Split-Recursive -Indices $right -MaxSize $MaxSize
    
    return $result
}
function Cluster-Places {
    param(
        [Parameter(Mandatory)]
        [array]$Indices,
        [int]$MaxSize = 3
    )
    $clusters = [System.Collections.ArrayList]::new()
    foreach ($c in (Split-Recursive -Indices $Indices -MaxSize $MaxSize)) {
        [void]$clusters.Add(@($c.Cluster))
    }

    return [System.Collections.ArrayList]$clusters
}

$clusters = Cluster-Places @(0..20)
$clusters | ForEach-Object { $_ -join ',' }
