function Start-Optimizer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Page,     # 任意の HTML ページ

        [Parameter()]
        [object[]]$PSO = $null     # GPX の PSO 配列
    )

    # RunApp に渡す StartScript
    $start = {
        param($State, $data)
        Run-TSPSolver -Places $data -State $State
    }

    $Routes = @{
        Start     = { param($d, $rh) $rh.Start($d) }
        Stop      = { param($d, $rh) $rh.Stop() }

        Status    = {
            param($d, $rh)
            return @{
                Generation = $rh.State.Generation
                UpdatedAt  = $rh.State.UpdatedAt
                Phase      = $rh.State.Phase      
                Result     = $rh.State.Result
            }
        }
        TSPSolver = {
            param($d, $rh)
            $State = Run-TSPSolver -Places $d -State @{}
            return $State.Result.Route
        }
        MeshCluster = {
            param($d, $rh)
            $State = Cluster-Mesh -Places $d -State @{}
            return $State.Result.Clusters
        }
        KMeansCluster = {
            param($d, $rh)
            $State = Cluster-KMeans -Places $d -State @{}
            return $State.Result.Clusters
        }
    }        

    # ★ Routes は指定しない（RunApp が標準 API を自動生成）
    Run-App -StartScript $start `
        -ModulePath $script:ModuleRoot `
        -Routes $Routes `
        -PageName $Page `
        -InitialData $PSO
}