Add-Type -AssemblyName PresentationFramework

# XAML 読み込み
$xamlPath = "D:\tool\Repository\PSTools\開発中\GUI\GUI.xaml"
$xaml = Get-Content $xamlPath -Raw
[xml]$xml = $xaml
$reader = New-Object System.Xml.XmlNodeReader $xml
$window = [Windows.Markup.XamlReader]::Load($reader)

$RunButton  = $window.FindName("RunButton")
$ConsoleBox = $window.FindName("ConsoleBox")
$InputBox   = $window.FindName("InputBox")

$global:psProcess = $null

# 入力送信
$InputBox.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq "Enter" -and $global:psProcess) {
        $text = $InputBox.Text
        $InputBox.Clear()
        $global:psProcess.StandardInput.WriteLine($text)
    }
})

# 実行ボタン
$RunButton.Add_Click({

    $ConsoleBox.Clear()

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"

    # ✅ 対話モードで起動（これが Read-Host を動かす唯一の方法）
    $psi.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -Command -"

    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.RedirectStandardInput  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $global:psProcess = New-Object System.Diagnostics.Process
    $global:psProcess.StartInfo = $psi
    $global:psProcess.Start() | Out-Null

    # ✅ 標準出力
    $actionOut = [System.Action]{
        while (-not $global:psProcess.HasExited) {
            $line = $global:psProcess.StandardOutput.ReadLine()
            if ($line -ne $null) {
                $window.Dispatcher.Invoke({
                    $ConsoleBox.AppendText($line + "`n")
                    $ConsoleBox.ScrollToEnd()
                })
            }
        }
    }

    # ✅ 標準エラー
    $actionErr = [System.Action]{
        while (-not $global:psProcess.HasExited) {
            $line = $global:psProcess.StandardError.ReadLine()
            if ($line -ne $null) {
                $window.Dispatcher.Invoke({
                    $ConsoleBox.AppendText("[ERR] $line`n")
                    $ConsoleBox.ScrollToEnd()
                })
            }
        }
    }

    [System.Threading.Tasks.Task]::Run($actionOut)
    [System.Threading.Tasks.Task]::Run($actionErr)

    # ✅ 起動後に Test.ps1 を実行させる
    Start-Sleep -Milliseconds 300
    $global:psProcess.StandardInput.WriteLine(". 'D:\tool\Repository\PSTools\開発中\GUI\Test.ps1'")
})

$window.ShowDialog() | Out-Null