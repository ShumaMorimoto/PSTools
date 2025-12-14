Add-Type -AssemblyName PresentationFramework

# --- XAML ---
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='GPX 分割ツール' Height='350' Width='500'>
    <Grid Margin='10'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>

        <!-- InputFile -->
        <StackPanel Grid.Row='0' Orientation='Horizontal'>
            <TextBlock Text='入力GPX:' VerticalAlignment='Center'/>
            <TextBox x:Name='InputFileBox' Width='300' Margin='10,0,0,0'/>
            <Button x:Name='BrowseButton' Content='参照' Width='60' Margin='10,0,0,0'/>
        </StackPanel>

        <!-- DistanceKm -->
        <StackPanel Grid.Row='1' Orientation='Horizontal' Margin='0,10,0,0'>
            <TextBlock Text='距離(km):' VerticalAlignment='Center'/>
            <TextBox x:Name='DistanceBox' Width='80' Margin='10,0,0,0' Text='0.0'/>
        </StackPanel>

        <!-- PointLimit -->
        <StackPanel Grid.Row='2' Orientation='Horizontal' Margin='0,10,0,0'>
            <TextBlock Text='ポイント上限:' VerticalAlignment='Center'/>
            <TextBox x:Name='PointLimitBox' Width='80' Margin='10,0,0,0' Text='40'/>
        </StackPanel>

        <!-- Output -->
        <TextBox x:Name='OutputBox' Grid.Row='3' Margin='0,10,0,10'
                 IsReadOnly='True' TextWrapping='Wrap'
                 VerticalScrollBarVisibility='Auto'/>

        <!-- Run -->
        <Button x:Name='RunButton' Grid.Row='4' Height='30'
                Content='実行' />
    </Grid>
</Window>
"@

# --- Load XAML ---
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$BrowseButton   = $window.FindName("BrowseButton")
$RunButton      = $window.FindName("RunButton")
$InputFileBox   = $window.FindName("InputFileBox")
$DistanceBox    = $window.FindName("DistanceBox")
$PointLimitBox  = $window.FindName("PointLimitBox")
$OutputBox      = $window.FindName("OutputBox")

# --- 実行するスクリプト ---
$scriptPath = "D:\tool\Repository\PSTools\RouteOptimizer\Sample\Split-Gpx.ps1"
$pwsh = "C:\Program Files\PowerShell\7\pwsh.exe"

# --- ファイル選択 ---
$BrowseButton.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "GPX Files (*.gpx)|*.gpx|All Files (*.*)|*.*"
    if ($dlg.ShowDialog()) {
        $InputFileBox.Text = $dlg.FileName
    }
})

# --- 非同期実行 ---
$RunButton.Add_Click({
    $OutputBox.Clear()

    $inputFile  = $InputFileBox.Text
    $distance   = $DistanceBox.Text
    $pointLimit = $PointLimitBox.Text

    if (-not (Test-Path $inputFile)) {
        $OutputBox.Text = "❌ 入力ファイルが存在しません"
        return
    }

    # 引数組み立て
    $argString = "-ExecutionPolicy Bypass -File `"$scriptPath`" -InputFile `"$inputFile`" -DistanceKm $distance -PointLimit $pointLimit"

    # ✅ Action に渡すためローカル変数へコピー
    $localPwsh     = $pwsh
    $localArgs     = $argString
    $localWindow   = $window
    $localOutput   = $OutputBox

    # ✅ Action（純粋 .NET のみ）
    $action = [System.Action]{
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $localPwsh
        $psi.Arguments = $localArgs
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::new()
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null

        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        $script:TaskResult = @{
            Out = $stdout
            Err = $stderr
        }
    }

    # ✅ 非同期実行 + UI 更新
    [System.Threading.Tasks.Task]::Run($action).ContinueWith({
        $localWindow.Dispatcher.Invoke({
            if ($script:TaskResult.Out) { $localOutput.AppendText($script:TaskResult.Out) }
            if ($script:TaskResult.Err) { $localOutput.AppendText("`r`n[ERROR]`r`n" + $script:TaskResult.Err) }
        })
    })
})

$window.ShowDialog() | Out-Null