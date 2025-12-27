#モジュールルートの設定
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─── DLL 読み込み ───
if (Test-Path "$PSScriptRoot\lib") {
    Get-ChildItem "$PSScriptRoot\lib\*.dll" | ForEach-Object {
        Add-Type -Path $_.FullName
    }
}

# ─── クラス定義 ───
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


# ─── 関数読み込み ───
foreach ($folder in @('Common', 'Extensions', 'Private', 'Public')) {
    if (Test-Path "$PSScriptRoot\$folder") {
        Get-ChildItem "$PSScriptRoot\$folder\*.ps1" | ForEach-Object {
            . $_.FullName
        }
    }
}

# ─── 公開関数 ───
$publicFunctions = @()
if (Test-Path "$PSScriptRoot\Public") {
    $publicFunctions = Get-ChildItem "$PSScriptRoot\Public\*.ps1" | ForEach-Object {
        [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    }
}
Export-ModuleMember -Function $publicFunctions

# ─── モジュール初期化 ───
Enable-ModuleSettings
