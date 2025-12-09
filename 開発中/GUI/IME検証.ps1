Add-Type -AssemblyName PresentationFramework

# ウィンドウとComboBox作成
$window = New-Object Windows.Window
$window.Title = "SearchCombo Test"
$window.Width = 400
$window.Height = 200

$combo = New-Object Windows.Controls.ComboBox
$combo.IsEditable = $true
$combo.Margin = "20"
$window.Content = $combo

# ロジック初期化
function Init-SearchComboLogic {
    param($Control)

    $Control.Tag = @{
        RefreshList = { param($text) Write-Host "→ Refresh: Text=[$text]" }
        Entered     = { param($text) Write-Host "→ Entered: Text=[$text]" }
    }

    # TextInputEvent: 通常入力 or IME確定
    $Control.AddHandler(
        [System.Windows.Input.TextCompositionManager]::TextInputEvent,
        [System.Windows.Input.TextCompositionEventHandler]{ param($s,$e)
            Write-Host "TextInputEvent: e.Text=[$($e.Text)] Combo.Text=[$($s.Text)]"
            $s.Tag.RefreshList.Invoke([string]$s.Text)
        },
        $true
    )

    # KeyDown(Return): 通常Enter or IME確定後のEnter
    $Control.Add_KeyDown({
        param($sender,$e)
        if ($e.Key -eq [System.Windows.Input.Key]::Return) {
            Write-Host "KeyDown(Return): Combo.Text=[$($sender.Text)]"
            $sender.Tag.Entered.Invoke([string]$sender.Text)
        }
    }.GetNewClosure())
}

Init-SearchComboLogic $combo

# ウィンドウ表示
$window.ShowDialog() | Out-Null