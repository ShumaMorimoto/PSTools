# =============================================================================
# PowerShell WPF: TextBox/ComboBox 入力イベント制御【ベースコード準拠・最終版】
# =============================================================================

# 必要なWPFアセンブリを読み込む
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# --- UIを定義するXAML ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TextBox &amp; ComboBox Event Control (Working Base)" Height="450" Width="500"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Label Grid.Row="0" Content="TextBoxでの入力:" FontWeight="Bold"/>
        <TextBox x:Name="MyTextBox" Grid.Row="1" FontSize="14" Margin="0,0,0,10"/>

        <Label Grid.Row="2" Content="ComboBoxでの入力 (IsEditable='True'):" FontWeight="Bold"/>
        <ComboBox x:Name="MyComboBox" Grid.Row="3" FontSize="14" IsEditable="True">
            <ComboBoxItem Content="選択肢 A"/> <ComboBoxItem Content="選択肢 B"/> <ComboBoxItem Content="選択肢 C"/>
        </ComboBox>

        <Label Grid.Row="4" Content="イベントログ:" FontWeight="Bold" Margin="0,15,0,0"/>
        <TextBox x:Name="LogBox" Grid.Row="5" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" Background="#f0f0f0"/>
    </Grid>
</Window>
"@

# --- PowerShell スクリプト本体 ---

try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
} catch { Write-Error "XAMLの読み込みに失敗しました。: $($_.Exception.Message)"; return }

$MyTextBox = $window.FindName("MyTextBox")
$MyComboBox = $window.FindName("MyComboBox")
$LogBox = $window.FindName("LogBox")

# --- イベント制御ロジック ---

# 処理A: テキストが変更されたときに実行
function Invoke-ActionA {
    param(
        [Parameter(Mandatory=$true)] $Control,
        [string]$Reason # 呼び出し理由をログに残すため
    )
    $Control.Dispatcher.InvokeAsync({
        $currentText = $Control.Text
        $controlName = $Control.Name
        $LogBox.AppendText("[$($controlName)] 【処理A - $Reason】 '$($currentText)'`n")
        $LogBox.ScrollToEnd()
    }, "Background") | Out-Null
}

# 処理B: 入力完了のEnterキーで実行
function Invoke-ActionB {
    param(
        [Parameter(Mandatory=$true)] $Control
    )
    $Control.Dispatcher.InvokeAsync({
        $currentText = $Control.Text
        $controlName = $Control.Name
        $LogBox.AppendText("[$($controlName)] 【処理B - 入力完了Enter】 '$($currentText)'`n")
        $LogBox.ScrollToEnd()
    }, "Background") | Out-Null
}

# 無視するキーのリスト (元のコードから引用)
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

# Enterキーが押される直前のテキストを保存する変数
$script:textBeforeEnter = $null

$OnKeyDown = {
    param($sender, $e)

    # Enterキーが押されたら、その時点のテキストを保存して一旦処理を抜ける
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        $script:textBeforeEnter = $sender.Text
        return
    }

    # 無視するキーリストにあれば何もしない
    if ($keysToIgnore.Contains($e.Key)) { return }
    
    # IMEによって処理されたキーイベントの場合も何もしない (元のコードのロジックを尊重)
    if ($e.ImeProcessed) { return }

    # 上記以外(通常の文字入力)の場合、遅延させて処理Aを実行
    # (KeyDown時点ではまだ文字が反映されていないため、少し待つ)
    Start-Sleep -Milliseconds 10
    Invoke-ActionA -Control $sender -Reason "通常入力"
}

$OnKeyUp = {
    param($sender, $e)

    # Enterキーが離された時だけ判定処理を行う
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        
        $currentText = $sender.Text
        
        # KeyDown時とテキストが変わっていれば、IME変換確定と判断 -> 処理A
        if ($script:textBeforeEnter -ne $currentText) {
            Invoke-ActionA -Control $sender -Reason "IME変換確定"
        }
        # テキストが変わっていなければ、入力完了のEnterと判断 -> 処理B
        else {
            Invoke-ActionB -Control $sender
        }
        
        # 次回のために変数をクリア
        $script:textBeforeEnter = $null
    }
}

# --- イベントハンドラを登録 ---
$controlsToWatch = @($MyTextBox, $MyComboBox)

foreach ($ctrl in $controlsToWatch) {
    $ctrl.add_KeyDown($OnKeyDown)
    $ctrl.add_KeyUp($OnKeyUp)
}

# --- ウィンドウを表示 ---
$LogBox.AppendText("準備完了。TextBoxまたはComboBoxにテキストを入力してください...`n`n")
$window.ShowDialog() | Out-Null
