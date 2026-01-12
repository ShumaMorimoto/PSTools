function Invoke-KMeansCluster {
    param(
        $InputData
    )

    # ログファイルのパス（モジュールルートや特定ディレクトリに合わせて調整してください）
#    $logFile = Join-Path $PSScriptRoot "execution.log"
#    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
#        $count = if ($null -ne $InputData) { $InputData.Count } else { 0 }
#        "[$timestamp] KMeansCluster: Start processing $count places." | Out-File $logFile -Append

        $State = Cluster-KMeans -Places $InputData -State @{}
        
 #       $clusterCount = if ($null -ne $State.Result.Clusters) { $State.Result.Clusters.Count } else { 0 }
 #       "[$timestamp] KMeansCluster: Success. Generated $clusterCount clusters." | Out-File $logFile -Append

        return $State.Result.Clusters
    }
    catch {
#      "[$timestamp] KMeansCluster: ERROR - $($_.Exception.Message)" | Out-File $logFile -Append
#        throw $_ # エラーはそのままPode側に投げて500エラーとして処理させる
    }
}