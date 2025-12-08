using module RouteOptimizer
using module GUITools

# === PlaceEntry クラス定義は省略（既存のまま） ===

# メインWindow
$window = New-Object System.Windows.Window
$window.Title  = "検索GUI"
$window.Width  = 800
$window.Height = 480

# ルートGrid（左右ペイン）
$rootGrid = New-Object System.Windows.Controls.Grid
$rootGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
$rootGrid.ColumnDefinitions[0].Width = "2*"   # 左ペイン
$rootGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
$rootGrid.ColumnDefinitions[1].Width = "3*"   # 右ペイン
$window.Content = $rootGrid

# -------------------------------
# 左ペイン（検索コンボ＋一覧）
# -------------------------------
$leftPanel = New-Object System.Windows.Controls.StackPanel
$leftPanel.Margin = "10"
[System.Windows.Controls.Grid]::SetColumn($leftPanel, 0)
$rootGrid.Children.Add($leftPanel)

# 検索コンボ
$combo = New-SearchCombo -Name "testplaces"
$combo.Width = 240
$combo.Tag.EntryClass = [PlaceEntry]
$leftPanel.Children.Add($combo)

# 結果グリッド
$dataGrid = New-ResultGrid -Name "ResultGrid"
$dataGrid.Margin = "0,10,0,0"
$dataGrid.VerticalAlignment = "Stretch"
$dataGrid.Height = [double]::NaN
$leftPanel.Children.Add($dataGrid)

# -------------------------------
# 右ペイン（詳細リスト）
# -------------------------------
$detailGrid = New-Object System.Windows.Controls.DataGrid
$detailGrid.AutoGenerateColumns = $false
$detailGrid.IsReadOnly = $true
$detailGrid.HeadersVisibility = "Column"
$detailGrid.Margin = "10"
[System.Windows.Controls.Grid]::SetColumn($detailGrid, 1)
$rootGrid.Children.Add($detailGrid)

# 列定義
$col1 = New-Object System.Windows.Controls.DataGridTextColumn
$col1.Header = "項目"
$col1.Binding = New-Object System.Windows.Data.Binding "項目"
$detailGrid.Columns.Add($col1)

$col2 = New-Object System.Windows.Controls.DataGridTextColumn
$col2.Header = "値"
$col2.Binding = New-Object System.Windows.Data.Binding "値"
$detailGrid.Columns.Add($col2)

# -------------------------------
# ステータスバー（下段にDockPanel）
# -------------------------------
$statusPanel = New-Object System.Windows.Controls.DockPanel
$statusPanel.LastChildFill = $true
$statusPanel.Margin        = "2,0,2,2"
$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Text               = "準備完了"
$statusText.VerticalAlignment  = "Center"
$statusText.FontSize           = 12
$statusText.Padding            = "2,2"
$statusPanel.Children.Add($statusText)

# Windowの下に配置
$window.Content = $rootGrid
$window.Add_Closed({ $statusPanel = $null })

function Set-Status([string]$msg) { $statusText.Text = $msg }

# -------------------------------
# 検索関数
# -------------------------------
function Invoke-Search([string]$keyword) {
    $towns   = ([GPXDocumentFactory]::Search($keyword)).GetTrkPts()
    $results = foreach ($town in $towns) { [PlaceEntry]::new($town) }
    return ,$results
}

# -------------------------------
# イベント連動
# -------------------------------
$combo.Tag.Entered = [Action[string]] {
    param($kw)
    if ([string]::IsNullOrWhiteSpace($kw)) { Set-Status "キーワードが空です"; return }
    Set-Status "検索中…"
    $results = Invoke-Search $kw
    & $dataGrid.Tag.SetData @($results)
    & $dataGrid.Tag.RefreshView @()
    Set-Status "検索完了（件数: $($results.Count)）"
}

$dataGrid.Tag.Selected = {
    param($entry)
    if ($null -eq $entry) { return }

    # 詳細ペインにプロパティ一覧を表示
    $detailGrid.ItemsSource = @(
        @{ 項目 = "拠点名"; 値 = $entry.拠点名 }
        @{ 項目 = "住所";   値 = $entry.住所 }
        @{ 項目 = "緯度";   値 = $entry.緯度 }
        @{ 項目 = "経度";   値 = $entry.経度 }
    )

    Set-Status "詳細を表示しました: $($entry.拠点名)"
}

# 表示
$window.ShowDialog() | Out-Null