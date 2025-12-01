Add-Type -AssemblyName PresentationFramework

# ウィンドウ作成
$window = New-Object System.Windows.Window
$window.Title = "ComboBox Test"
$window.Width = 400
$window.Height = 300

# コンボ部品生成
$comboBox = New-SearchCombo
$comboBox.ItemsSource = @("Apple","Banana","Cherry")

# 検索ロジック（外側）
function Invoke-Search($keyword) {
    Write-Host "検索実行 (外側): $keyword"
    # 疑似検索結果
    $results = @(
        [PSCustomObject]@{ Name = "$keyword-Result1" }
        [PSCustomObject]@{ Name = "$keyword-Result2" }
    )
    $resultsGrid.ItemsSource = $results
}

# 外側から検索ハンドラを注入
$comboBox.TagEntered = [Action[string]]{ param($kw) Invoke-Search $kw }

# 検索結果 Grid
$resultsGrid = New-Object System.Windows.Controls.DataGrid
$resultsGrid.Margin = "20"
$resultsGrid.Height = 100
$resultsGrid.AutoGenerateColumns = $true

# 結果確定時に履歴更新
$resultsGrid.Add_SelectionChanged({
    param($sender,$args)
    $selected = $sender.SelectedItem
    if ($selected -and $selected.Name) {
        $kw = [string]$selected.Name
        Write-Host "結果確定: $kw → TagHistory.Invoke"
        $comboBox.TagHistory.Invoke($kw)
    }
})

# 検索ボタン
$searchButton = New-Object System.Windows.Controls.Button
$searchButton.Content = "検索実行"
$searchButton.Margin = "20"
$searchButton.Add_Click({
    $kw = $comboBox.Text
    $comboBox.TagEntered.Invoke($kw)
})

# UI配置
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Children.Add($comboBox)
$panel.Children.Add($searchButton)
$panel.Children.Add($resultsGrid)
$window.Content = $panel

# 表示
$window.ShowDialog() | Out-Null