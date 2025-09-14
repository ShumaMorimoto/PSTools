# モジュールルートの定義（psm1の絶対パスから）
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# 関数読み込み
Get-ChildItem "$PSScriptRoot\Private\*.ps1" | ForEach-Object { . $_.FullName }
Get-ChildItem "$PSScriptRoot\Public\*.ps1"  | ForEach-Object { . $_.FullName }

# 初期化（設定パスの構築も含む）
Enable-ModuleSettings
