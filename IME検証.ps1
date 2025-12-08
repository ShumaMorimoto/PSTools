# =============================================================================
# PowerShell WPF: TextBoxとComboBoxへの入力イベント制御【修正版】
# (XAML内の特殊文字 '&' をエスケープ)
# =============================================================================

# 必要なWPFアセンブリを読み込む
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# --- UIを定義するXAML ---
# Title属性の '&' を '&amp;' に修正
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TextBox &amp; ComboBox Event Control" Height="450" Width="500"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Label Grid.Row="0" Content="TextBoxでの入力:" FontWeight="Bold"/>
        <TextBox x:Name="MyTextBox" Grid.Row="1" FontSize="14" Margin="0,0,0,10"/>

        <Label Grid.Row="2" Content="ComboBoxでの入力 (IsEditable='True'):" FontWeight="Bold"/>
        <ComboBox x:Name="MyComboBox" Grid.Row="3" FontSize="14" IsEditable="True">
            <ComboBoxItem Content="選択肢 A"/>
            <ComboBoxItem Content="選択肢 B"/>
            <ComboBoxItem Content="選択肢 C"/>
        </ComboBox>

        <Label Grid.Row="4" Content="イベントログ:" FontWeight="Bold" Margin="0,15,0,0"/>
        <TextBox x:Name="LogBox" Grid.Row="5" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" Background="#f0f0f0"/>
    </Grid>
</Window>
"@

# --- PowerShell スクリプト本体 ---

# XAMLからウィンドウオブジェクトを生成
try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "XAMLの読み込みに失敗しました。: $($_.Exception.Message)"
    return
}

# XAMLで定義したコントロールを変数に格納
$MyTextBox = $window.FindName("MyTextBox")
$MyComboBox = $window.FindName("MyComboBox")
$LogBox = $window.FindName("LogBox")


# --- イベント制御ロジック (TextBox, ComboBoxで共有) ---

$keysToIgnore = [System.Collections.Generic.HashSet[System.Windows.Input.Key]]@(
    [System.Windows.Input.Key]::LeftShift, [System.Windows.Input.Key]::RightShift,
    [System.Windows.Input.Key]::LeftCtrl, [System.Windows.Input.Key]::RightCtrl,
    [System.Windows.Input.Key]::LeftAlt, [System.Windows.Input.Key]::RightAlt,
    [System.Windows.Input.Key]::LWin, [System.Windows.Input.Key]::RWin, [System.Windows.Input.Key]::Apps,
    [System.Windows.Input.Key]::Up, [System.Windows.Input.Key]::Down, [System.Windows.Input.Key]::Left, [System.Windows.Input.Key]::Right,
    [System.Windows.Input.Key]::Home, [System.Windows.Input.Key]::End, [System.Windows.Input.Key]::PageUp, [System.Windows.Input.Key]::PageDown,
    [System.Windows.Input.Key]::F1, [System.Windows.Input.Key]::F2, [System.Windows.Input.Key]::F3, [System.Windows.Input.Key]::F4,
    [System.Windows.Input.Key]::F5, [System.Windows.Input.Key]::F6, [System.Windows.Input.Key]::F7, [System.Windows.Input.Key]::F8,
    [System.Windows.Input.Key]::F9, [System.Windows.Input.Key]::F10, [System.Windows.Input.Key]::F11, [System.Windows.Input.Key]::F12,
    [System.Windows.Input.Key]::CapsLock, [System.Windows.Input.Key]::NumLock, [System.Windows.Input.Key]::Scroll,
    [System.Windows.Input.Key]::Insert, [System.Windows.Input.Key]::PrintScreen, [System.Windows.Input.Key]::Pause,
    [System.Windows.Input.Key]::Tab, [System.Windows.Input.Key]::Escape
)

function Invoke-MyAction {
    param(
        [Parameter(Mandatory=$true)]
        $Control
    )
    $Control.Dispatcher.InvokeAsync({
        $currentText = $Control.Text
        $controlName = $Control.Name
        $formattedText = $currentText -replace "`r`n", "\n"
        
        $LogBox.AppendText("[$($controlName)] イベント実行！ テキスト: '$($formattedText)'`n")
        $LogBox.ScrollToEnd()
        
    }, "ContextIdle") | Out-Null
}

$OnKeyDown = {
    param($sender, $e)
    if ($e.ImeProcessed) { return }
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) { return }
    if ($keysToIgnore.Contains($e.Key)) { return }
    Invoke-MyAction -Control $sender
}

$OnKeyUp = {
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        Invoke-MyAction -Control $sender
    }
}

# --- イベントハンドラを登録 ---
$MyTextBox.add_KeyDown($OnKeyDown)
$MyTextBox.add_KeyUp($OnKeyUp)

$MyComboBox.add_KeyDown($OnKeyDown)
$MyComboBox.add_KeyUp($OnKeyUp)

# --- ウィンドウを表示 ---
$LogBox.AppendText("準備完了。TextBoxまたはComboBoxにテキストを入力してください...`n`n")
$window.ShowDialog() | Out-Null
