class RunspaceHost {
    [Runspace]$Runspace
    [PowerShell]$PS
    [hashtable]$State
    [object]$AsyncHandle
    [scriptblock]$StartScript

    RunspaceHost([string]$modulePath, [scriptblock]$startScript) {
        $iss = [InitialSessionState]::CreateDefault()
        $iss.ImportPSModule($modulePath)

        $this.Runspace = [RunspaceFactory]::CreateRunspace($iss)
        $this.Runspace.Open()

        $this.PS = [PowerShell]::Create()
        $this.PS.Runspace = $this.Runspace

        $this.State = [hashtable]::Synchronized(@{Stop = $false})
        $this.StartScript = $startScript
    }

    [object] Start([object]$data) {
        if ($this.AsyncHandle) { return @{ status = "already running" } }

        $this.State.Input = $data
        $this.State.Stop = $false

        $this.PS.Commands.Clear()
        $this.PS.AddScript($this.StartScript).AddArgument($this.State).AddArgument($data) | Out-Null

        $this.AsyncHandle = $this.PS.BeginInvoke()
        return @{ status = "started" }
    }

    [object] Stop() {
        if (-not $this.AsyncHandle) { return @{ status = "not running" } }

        $this.State.Stop = $true
        $this.PS.EndInvoke($this.AsyncHandle)
        $this.AsyncHandle = $null
        return @{ status = "stopped" }
    }
}

$startScript = {
    param($State,$data)
    RunGALogic -State $State -Places $data 
}

$Routes = @{
    Start   = { param($data) $runhost.Start($data) }   # 汎用
    Stop    = { param($data) $runhost.Stop() }         # 汎用
    Status  = { param($data)                       # カスタム
        @{
            Generation = $runhost.State.Generation
            UpdatedAt  = $runhost.State.UpdatedAt
            BestDist   = $runhost.State.BestDist
        }
    }
    GetBest = { param($data)                       # カスタム
        $runhost.State.BestRoute | ForEach-Object {
            $runhost.State.Places[$_]
        }
    }
}

