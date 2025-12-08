Add-Type -AssemblyName PresentationFramework

# --- カスタマイズ変数（冒頭） ---
$MainWindowXamlPath = "D:\tool\Repository\PSTools\GUITools\data\MainWindow.xaml"
$ControlsXamlPath   = "D:\tool\Repository\PSTools\GUITools\data\Controls.xaml"
$EntryType          = [EntryBase]   # デフォルトは EntryBase

# --- UIロード ---
[xml]$xaml        = Get-Content $MainWindowXamlPath
$reader           = New-Object System.Xml.XmlNodeReader $xaml
$window           = [System.Windows.Markup.XamlReader]::Load($reader)

[xml]$controlsXml = Get-Content $ControlsXamlPath
$reader2          = New-Object System.Xml.XmlNodeReader $controlsXml
$dict             = [System.Windows.Markup.XamlReader]::Load($reader2)

# --- 差し込み ---
($window.FindName("SearchComboHost")).Content = $dict["SearchCombo"]
($window.FindName("ResultGridHost")).Content  = $dict["ResultGrid"]
($window.FindName("DetailGridHost")).Content  = $dict["DetailGrid"]

# --- ステータス ---
$statusText = $window.FindName("StatusText")
$SetStatus = {
    param([string]$Level, [string]$Area, [string]$Message)
    $update = { $statusText.Text = "[$Level][$Area] $Message" }
    if ($statusText.Dispatcher.CheckAccess()) { & $update }
    else { $null = $statusText.Dispatcher.Invoke([Action]$update) }
}
$SetStatus.Invoke("Info","Framework","レイアウト準備完了")

# --- 部品初期化 ---
Init-SearchComboLogic -control $dict["SearchCombo"] -Name "SearchCombo" -SetStatus $SetStatus
Init-ResultGridLogic  -control $dict["ResultGrid"]  -Name "ResultGrid"  -SetStatus $SetStatus
Init-DetailGridLogic  -control $dict["DetailGrid"]  -Name "DetailGrid"  -SetStatus $SetStatus

# --- 拡張ポイント実装サンプル ---

# コンボ: Entered（選択確定時 → 結果GRIDに反映）
$dict["SearchCombo"].Tag.Entered = {
    param($entry)
    $dict["ResultGrid"].ItemsSource = @($entry)   # 単一選択を結果に表示
    $SetStatus.Invoke("Info","SearchCombo","選択確定 → 結果GRIDへ反映")
}.GetNewClosure()

# 結果GRID: Selected（選択確定時 → 詳細GRIDに反映）
$dict["ResultGrid"].Tag.Selected = {
    param($entry)
    $dict["DetailGrid"].Tag.SetData.Invoke($entry)
    $SetStatus.Invoke("Info","ResultGrid","選択確定 → 詳細GRIDへ反映")
}.GetNewClosure()

# 詳細GRID: Entered（詳細表示確定時 → ログ出力）
$dict["DetailGrid"].Tag.Entered = {
    param($entry)
    Write-Host "詳細表示完了: $($entry.名称) [$($entry.緯度),$($entry.経度)]"
    $SetStatus.Invoke("Info","DetailGrid","詳細表示完了 → ログ出力")
}.GetNewClosure()

# --- 表示 ---
$window.ShowDialog() | Out-Null