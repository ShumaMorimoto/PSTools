class GAOptimizer {
    [hashtable]$State
    [System.Management.Automation.PowerShell]$PS
    [System.Management.Automation.Runspaces.Runspace]$Runspace
    [object]$asyncHandle
    [array]$initialPlaces

    GAOptimizer() {
        $this.State = [hashtable]::Synchronized(@{
                Stop       = $false
                BestDist   = [double]::PositiveInfinity
                BestRoute  = $null
                Generation = 0
                UpdatedAt  = [datetime]::MinValue
            })
    }

    [void] Start([array]$Places) {
        $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $iss.ImportPSModule('H:\tool\Repositories\PSTools\開発中\GPX3\GA\galogic.ps1')  # この一行で Runspace 内に GALogic をロード

        $this.Runspace = [runspacefactory]::CreateRunspace($iss)
        $this.Runspace.Open()

        $this.PS = [powershell]::Create()
        $this.PS.Runspace = $this.Runspace
        $this.State.Places = $Places   # ★追加

        $script = {
            param($State, $Places)
            # RunGA を呼ぶだけ
            RunGALogic -Places $Places -State $State
        }

        $this.PS.AddScript($script).AddArgument($this.State).AddArgument($Places) | Out-Null
        $this.asyncHandle = $this.PS.BeginInvoke()
    }

    [hashtable] Status() {
        return @{
            Generation = $this.State.Generation
            UpdatedAt  = $this.State.UpdatedAt
            BestDist   = $this.State.BestDist
        }
    }

    [array] GetBest() {
        # $Places     : オブジェクトの配列
        # $BestRoute  : 並び順を示す int[] （$Places のインデックス）

        $SortedPlaces = $this.State.BestRoute | ForEach-Object { $this.State.Places[$_] }
        return $SortedPlaces
    }

    [void] Stop() {
        $this.State.Stop = $true
        $this.PS.EndInvoke($this.asyncHandle)
        $this.PS.Dispose()
        $this.Runspace.Close()
    }
}

$N = 100
$places = 1..$N | ForEach-Object {
    [PSCustomObject]@{
        lat = Get-Random -Minimum 0 -Maximum 100
        lon = Get-Random -Minimum 0 -Maximum 100
    }
}

$ga = [GAOptimizer]::new()
$ga.Start($places)

for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep 0.5
    $status = $ga.Status()
    "Gen=$($status.Generation) BestDist=$($status.BestDist) Route=$($status.BestRoute -join ',')"
}

$ga.GetBest()

$ga.Stop()
