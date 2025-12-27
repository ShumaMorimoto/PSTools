function Test-GASimulation {
    param(
        [object] $Places = $null,
        [int] $N = 100,
        [int] $NumClusters = 50,
        [int] $PopSizePerCluster = 50,
        [int] $PopSizeClustersOrder = 100,
        [int] $MaxGen = 50
    )
    
    if (-not $Places) {
        $Places = 1..$N | ForEach-Object { [PSCustomObject]@{ lat = Get-Random -Minimum 33.5 -Maximum 33.6; lon = Get-Random -Minimum 134.0 -Maximum 134.1 } }
    }

    $state = @{
        Stop = $false
    }
    
    Run-GASimulation -Places $Places -State $state -NumClusters $NumClusters -PopSizePerCluster $PopSizePerCluster -PopSizeClustersOrder $PopSizeClustersOrder -MaxGen $MaxGen
    "Gen: $($state.Generation), BestDist: $([math]::Round($state.BestDist,3))"
}
