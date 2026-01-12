
$modulePath = "D:\tool\tmp\開発中\GA\GaFunctions.ps1"

# Runspace 作成
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()

$ps = [powershell]::Create()
$ps.Runspace = $runspace

# ScriptBlock 内で Import-Module
$ps.AddScript({
    param($modPath)
    Import-Module $modPath -Force
    Test-GA 123
     "aaa"
}).AddArgument($modulePath)

# 実行
$handle = $ps.BeginInvoke()
$result = $ps.EndInvoke($handle)
$result

# 後処理
$ps.Dispose()
$runspace.Close()
