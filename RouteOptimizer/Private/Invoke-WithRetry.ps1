function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action,
        [int]$MaxRetry = 3,
        [int]$DelaySec = 2
    )

    for ($i = 1; $i -le $MaxRetry; $i++) {
        try {
            return & $Action
        }
        catch {
            Write-Warning "試行 $i/$MaxRetry 失敗: $($_.Exception.Message)"
            if ($i -lt $MaxRetry) {
                Start-Sleep -Seconds $DelaySec
            }
            else {
                throw
            }
        }
    }
}