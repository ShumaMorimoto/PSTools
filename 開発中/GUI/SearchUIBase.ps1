# 必要アセンブリをロード
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

# メインWindow（全体のベース）
$window = New-Object System.Windows.Window
$window.Title = "検索GUI"
$window.Width = 600
$window.Height = 420

# Gridレイアウト（2行: 上=メイン, 下=ステータス表示）
$grid = New-Object System.Windows.Controls.Grid
$rowMain   = New-Object System.Windows.Controls.RowDefinition
$rowStatus = New-Object System.Windows.Controls.RowDefinition
$rowStatus.Height = "30"   # ステータスバー高さを固定（約2行分）
$grid.RowDefinitions.Add($rowMain)
$grid.RowDefinitions.Add($rowStatus)
$window.Content = $grid

# 上段のレイアウト（StackPanel）
$topPanel = New-Object System.Windows.Controls.StackPanel
$topPanel.Margin = "10"
[System.Windows.Controls.Grid]::SetRow($topPanel,0)
$grid.Children.Add($topPanel)

# --- (1) 検索コンボ部品 ---
# ComboBox（キーワード入力）
# → 部品化対象：検索履歴管理や入力補助を含めた「検索コンボ」モジュールに切り出す
$combo = New-Object System.Windows.Controls.ComboBox
$combo.IsEditable = $true
$combo.Width = 240
$combo.ItemsSource = @("りんご","みかん","バナナ")
$topPanel.Children.Add($combo)

# --- (2) 結果グリッド部品 ---
# DataGrid（検索結果表示）
# → 部品化対象：検索結果のバインド・列定義・選択イベントを含めた「結果グリッド」モジュールに切り出す
$dataGrid = New-Object System.Windows.Controls.DataGrid
$dataGrid.Margin = "0,10,0,0"
$dataGrid.AutoGenerateColumns = $true
$dataGrid.Height = 300
$topPanel.Children.Add($dataGrid)

# --- ステータスバー（共通部品） ---
# DockPanel + TextBlock で代替
$statusPanel = New-Object System.Windows.Controls.DockPanel
$statusPanel.LastChildFill = $true
$statusPanel.Margin = "2,0,2,2"
[System.Windows.Controls.Grid]::SetRow($statusPanel,1)
$grid.Children.Add($statusPanel)

$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Text = "準備完了"
$statusText.VerticalAlignment = "Center"
$statusText.FontSize = 12
$statusText.Padding = "2,2"
$statusPanel.Children.Add($statusText)

# ステータスメッセージ更新関数（共通ユーティリティ）
function Set-Status([string]$msg) {
    $statusText.Text = $msg
}

# ダミー検索関数（差し替え可能）
# → 部品化対象：検索ロジックを外部モジュールに切り出し
function Invoke-Search([string]$keyword) {
    @(
        @{Name="結果1_$keyword"; Info="詳細A"}
        @{Name="結果2_$keyword"; Info="詳細B"}
        @{Name="結果3_$keyword"; Info="詳細C"}
    )
}

# 検索コンボのイベント（Enterキーで検索実行）
# → 部品化対象：検索コンボのイベントハンドラをモジュール化
$combo.Add_KeyDown({
    param($sender, [System.Windows.Input.KeyEventArgs]$e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        $keyword = $combo.Text
        if ([string]::IsNullOrWhiteSpace($keyword)) {
            Set-Status "キーワードが空です"
            return
        }
        Set-Status "検索中…"

        $results = Invoke-Search $keyword
        $dataGrid.ItemsSource = $results

        if (-not $combo.Items.Contains($keyword)) { $combo.Items.Add($keyword) }

        Set-Status "検索完了（件数: $($results.Count)）"
    }
})

# 結果グリッドのイベント（ダブルクリックで詳細表示）
# --- (3) 詳細リスト部品 ---
# → 部品化対象：詳細ウィンドウ＋詳細リスト＋コピー機能を「詳細リスト」モジュールに切り出す
$dataGrid.Add_MouseDoubleClick({
    param($sender, $e)
    if (-not $dataGrid.SelectedItem) { return }
    $selected = $dataGrid.SelectedItem

    # 詳細Window
    $detailWin = New-Object System.Windows.Window
    $detailWin.Title = "詳細情報: $($selected.Name)"
    $detailWin.Width = 360
    $detailWin.Height = 300

    # メインWindowをオーナーに設定し中央表示
    $detailWin.Owner = $window
    $detailWin.WindowStartupLocation = "CenterOwner"

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = "10"
    $detailWin.Content = $panel

    # 詳細DataGrid（複数選択可能）
    $detailGrid = New-Object System.Windows.Controls.DataGrid
    $detailGrid.AutoGenerateColumns = $true
    $detailGrid.SelectionMode = "Extended"   # 複数選択
    $detailGrid.SelectionUnit = "FullRow"
    $detailGrid.Height = 200
    $detailGrid.ItemsSource = @(
        @{Detail="詳細1_$($selected.Name)"}
        @{Detail="詳細2_$($selected.Name)"}
        @{Detail="詳細3_$($selected.Name)"}
    )
    $panel.Children.Add($detailGrid)

    # コピー用ボタン
    $copyButton = New-Object System.Windows.Controls.Button
    $copyButton.Content = "選択をまとめてコピー"
    $copyButton.Margin = "0,8,0,0"
    $copyButton.Add_Click({
        param($s,$args)
        if ($detailGrid.SelectedItems.Count -le 0) {
            [System.Windows.MessageBox]::Show("選択がありません")
            return
        }
        $clipText = ($detailGrid.SelectedItems | ForEach-Object { $_.Detail }) -join "`r`n"
        [System.Windows.Clipboard]::SetText($clipText)
        Set-Status "コピーしました（$($detailGrid.SelectedItems.Count) 件）"
        [System.Windows.MessageBox]::Show("コピーしました:`n$clipText")
    })
    $panel.Children.Add($copyButton)

    $detailWin.ShowDialog() | Out-Null
})

# 表示
$window.ShowDialog() | Out-Null