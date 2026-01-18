function Invoke-KMeansCluster {
    param(
        $InputData
    )

    # places を C# 用に変換
    $placesCsp = $InputData | ForEach-Object {
        [ValueTuple[double,double]]::new($_.lat, $_.lon)
    }

    $Clusters = [TspSolverLib.Clustering]::KMeansCluster($placesCsp)

    return ,$Clusters
}