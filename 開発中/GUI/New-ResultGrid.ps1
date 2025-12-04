Add-Type -AssemblyName PresentationFramework

# ===== EntryBase / Entry（既存定義を前提。簡易再掲） =====

# ================================
# DataGrid生成関数（resultもEntry配列前提）
# ================================
function New-ResultGrid {
    param([string]$Name)

    $grid = New-Object Windows.Controls.DataGrid
    $grid.Margin = "10"
    $grid.Height = 300
    $grid.FontSize = 16
    $grid.AutoGenerateColumns = $true
    $grid.IsReadOnly = $true
    $grid.SelectionMode = "Single"
    $grid.SelectionUnit = "FullRow"

    # "_" 始まりの列はキャンセル
    $grid.Add_AutoGeneratingColumn({
            param($sender, $e)
            if ($e.PropertyName -match '^_') { $e.Cancel = $true }
        })

    $gridref = $grid
    $grid.Tag = @{
        Name           = $Name
        HighlightBrush = [Windows.Media.Brushes]::LightYellow
        SelectionBrush = [Windows.Media.Brushes]::LightGreen

        # UpdateGrid: Entry配列同士を突合せ
        UpdateGrid     = {
            param([EntryBase[]]$results, [EntryBase[]]$history)

            foreach ($r in $results) {
                $isMatch = $false
                foreach ($h in $history) {
                    if ($h.Equals($r)) { $isMatch = $true; break }
                }
                $r | Add-Member -NotePropertyName _IsHistoryMatch -NotePropertyValue $isMatch -Force
            }

            $sorted = $results | Sort-Object { -not $_._IsHistoryMatch }
            $gridref.ItemsSource = @($sorted)
        }.GetNewClosure()

        # 外部から差し替え可能な Selected スクリプト
        Selected       = { param($entry) Write-Host "Tag.Selected: $($entry.ToString())" }
    }

    # 履歴一致行を色付け
    $grid.Add_LoadingRow({
            param($sender, $e)
            $item = $e.Row.Item
            if ($item._IsHistoryMatch) { $e.Row.Background = $sender.Tag.HighlightBrush }
        })

    # 選択イベント
    $grid.Add_SelectionChanged({
            param($sender, $e)
            $selected = $sender.SelectedItem
            if ($selected) {
                $row = $sender.ItemContainerGenerator.ContainerFromItem($selected)
                if ($row -is [Windows.Controls.DataGridRow]) { $row.Background = $sender.Tag.SelectionBrush }

                # 内部ログ
                Write-Host "選択された: $($selected.ToString())"

                # 外部スクリプト呼び出し（Invoke の挙動確認済み）
                $sender.Tag.Selected.Invoke($selected)
            }
        })

    return $grid
}

# ================================
# ダミーデータ（結果もEntry配列）
# ================================
$results = @(
    [Entry]::new("41.773", "函館駅"),
    [Entry]::new("43.068", "札幌駅"),
    [Entry]::new("35.681", "東京駅")
)

# 履歴（Entry配列）
$history = @(
    [Entry]::new("41.773", "函館駅")  # 函館駅
)

# ================================
# Grid生成と更新
# ================================
$datagrid = New-ResultGrid -Name "TestGrid"
$datagrid.Tag.UpdateGrid.Invoke($results, $history)

# ================================
# ウィンドウ表示
# ================================
$window = New-Object Windows.Window
$window.Title = "UpdateGrid テスト（Entry配列前提）"
$window.Width = 500
$window.Height = 400
$window.Content = $datagrid
#$window.ShowDialog() | Out-Null