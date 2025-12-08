Add-Type -AssemblyName PresentationFramework

# 部品をインスタンス化
$combo    = New-UIElement -ElementKey "SearchCombo"
$dataGrid = New-UIElement -ElementKey "ResultGrid"

# Windowに貼り付け
$window = New-Object System.Windows.Window
$window.Title = "検索GUI"
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Children.Add($combo)
$panel.Children.Add($dataGrid)
$window.Content = $panel

# Initでロジック注入
Init-SearchComboLogic -comboBox $combo -Name "testplaces" -EntryClass [PlaceEntry]
Init-ResultGridLogic -grid $dataGrid

# 表示
$window.ShowDialog() | Out-Null