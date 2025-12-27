function Start-Optimizer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Page,     # 任意の HTML ページ

        [Parameter()]
        [object[]]$PSO = $null     # GPX の PSO 配列
    )

    # GPXTools モジュールのルートを取得
    $moduleRoot = $MyInvocation.MyCommand.Module.ModuleBase

    # RunApp に渡す StartScript
    $start = {
        param($State, $data)
        Run-GASimulation -Places $data -State $State
    }

    # Routes は GPXTools が提供
    $routes = @{
        Start    = { param($d,$rh) $rh.Start($d) }
        Stop     = { param($d,$rh) $rh.Stop() }
        Status   = { param($d,$rh) @{
            Generation = $rh.State.Generation
            UpdatedAt  = $rh.State.UpdatedAt
            BestDist   = $rh.State.BestDist
            BestRoute  = $rh.State.BestRoute
        }}
        GetBest  = { param($d,$rh) $rh.State.BestRoute | ForEach-Object {
            $rh.State.Places[$_]
        }}
        Optimize = { param($d,$rh) Optimize-AreaRoute $d }
    }

    # RunApp を起動
    Run-App -StartScript $start `
            -ModulePath $moduleRoot `
            -Routes $routes `
            -PageName $Page `
            -InitialData $PSO
}