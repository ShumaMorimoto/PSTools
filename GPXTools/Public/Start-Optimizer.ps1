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
        Run-GASimulation -Places $data -State $State
    }

    # ★ Routes は指定しない（RunApp が標準 API を自動生成）
    Run-App -StartScript $start `
            -ModulePath $script:ModuleRoot `
            -PageName $Page `
            -InitialData $PSO
}