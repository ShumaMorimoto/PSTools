class RunspaceHost {
    [Runspace]$Runspace
    [PowerShell]$PS
    [hashtable]$State
    [object]$AsyncHandle
    [scriptblock]$StartScript

    RunspaceHost([string[]]$ModulePath, [scriptblock]$StartScript) {

        # --- 初期セッション状態 ---
        $iss = [InitialSessionState]::CreateDefault()

        # --- モジュールを string[] のまま Import ---
        if ($ModulePath) {
            $iss.ImportPSModule($ModulePath)
        }

        # --- Runspace 作成 ---
        $this.Runspace = [RunspaceFactory]::CreateRunspace($iss)
        $this.Runspace.Open()

        # --- PowerShell インスタンス ---
        $this.PS = [PowerShell]::Create()
        $this.PS.Runspace = $this.Runspace

        # --- State 初期化 ---
        $this.State = [hashtable]::Synchronized(@{
                Stop       = $false
                Generation = 0
                UpdatedAt  = $null
                BestDist   = [double]::PositiveInfinity
                BestRoute  = @()
            })

        $this.StartScript = $StartScript
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
