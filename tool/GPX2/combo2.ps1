Add-Type -AssemblyName PresentationFramework

function New-SearchCombo {
    $combo = New-Object System.Windows.Controls.ComboBox
    $combo.IsEditable = $true
    $combo.Margin = "5"

    # TagEntered
    $combo | Add-Member -NotePropertyName TagEntered -NotePropertyValue (
        [Action[string]]{
            param($kw) ; Write-Host "TagEntered (default): $kw"
        }
    ) -Force

    # TagHistory
    $combo | Add-Member -NotePropertyName TagHistory -NotePropertyValue (
        [Action[string]]{
            param($kw)
            if (-not [string]::IsNullOrWhiteSpace($kw)) {
                if (-not $combo.Items.Contains($kw)) {
                    $combo.Items.Add($kw)
                    Write-Host "履歴更新 (Combo側): $kw"
                }
            }
        }
    ) -Force

    # Loaded → 内部 TextBox の KeyDown をフック
    $combo.Add_Loaded({
        param($sender,$args)
        $sender.ApplyTemplate()
        $editable = $sender.Template.FindName("PART_EditableTextBox",$sender)
        if (-not $editable) { return }

        $editable.Add_KeyDown({
            # $_ が KeyEventArgs
            $e = $_
            # $this が TextBox
            $textBox = $this
            # ComboBox を取得
            $comboRef = [System.Windows.Controls.ComboBox]$textBox.TemplatedParent
            if (-not $comboRef) { return }

            switch ($e.Key) {
                "Down" {
                    if ($comboRef.Items.Count -gt 0) {
                        $comboRef.IsDropDownOpen = $true
                        $comboRef.Focus()
                        $comboRef.SelectedIndex = 0
                        $e.Handled = $true
                        Write-Host "Down → open, select first"
                    }
                }
                "Tab" {
                    if ($comboRef.IsDropDownOpen -and $comboRef.SelectedItem) {
                        $comboRef.Text = $comboRef.SelectedItem
                        $comboRef.IsDropDownOpen = $false
                        $e.Handled = $true
                        Write-Host "Tab → apply selected"
                    }
                }
                "Return" {
                    $comboRef.IsDropDownOpen = $false
                    $e.Handled = $true
                    Write-Host "Enter → close"
                    $comboRef.TagEntered.Invoke($comboRef.Text)
                }
            }
        })
    })

    # SelectionChanged → TagEntered
    $combo.Add_SelectionChanged({
        param($sender,$args)
        if ($sender.SelectedItem) {
            $keyword = [string]$sender.SelectedItem
            Write-Host "Selection → TagEntered: $keyword"
            $sender.TagEntered.Invoke($keyword)
        }
    })

    return $combo
}


Add-Type -AssemblyName PresentationFramework

# ウィンドウ作成
$window = New-Object System.Windows.Window
$window.Title = "履歴更新テスト"
$window.Width = 400
$window.Height = 250

# コンボ生成
$comboBox = New-SearchCombo
$comboBox.ItemsSource = @("Apple","Banana","Cherry")

# 外側ロジック（TagEntered）
function Invoke-Search([string]$keyword) {
    Write-Host "検索実行 (外側): $keyword"
    # 検索確定時に履歴更新を呼ぶ
    $comboBox.TagHistory.Invoke($keyword)
}
$comboBox.TagEntered = [Action[string]]{ param($kw) Invoke-Search $kw }

# 検索ボタン（入力文字列を履歴に追加）
$searchButton = New-Object System.Windows.Controls.Button
$searchButton.Content = "検索実行"
$searchButton.Margin = "20"
$searchButton.Add_Click({
    $kw = $comboBox.Text
    $comboBox.TagEntered.Invoke($kw)
})

# 履歴テストボタン（固定文字列を履歴に追加）
$historyButton = New-Object System.Windows.Controls.Button
$historyButton.Content = "履歴追加テスト"
$historyButton.Margin = "20"
$historyButton.Add_Click({
    $comboBox.TagHistory.Invoke("TestHistory")
})

# UI配置
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Children.Add($comboBox)
$panel.Children.Add($searchButton)
$panel.Children.Add($historyButton)
$window.Content = $panel

# 表示
$window.ShowDialog() | Out-Null