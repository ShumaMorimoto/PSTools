Add-Type -AssemblyName PresentationFramework

# ================================
# DataGrid生成関数（新しい設計）
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

    # "_" 始まりの列は表示しない
    $grid.Add_AutoGeneratingColumn({
            param($sender, $e)
            if ($e.PropertyName -match '^_') { $e.Cancel = $true }
        })

    # $gridの参照をクロージャ内で使うための変数
    $gridref = $grid

    # --- Tagの設計を刷新 ---
    $grid.Tag = @{
        # --- 状態 ---
        Name           = $Name
        Items          = @()
        HighlightBrush = [Windows.Media.Brushes]::LightYellow
        SelectionBrush = [Windows.Media.Brushes]::LightGreen

        # --- 操作 ---

        # [メソッド1] 表示対象のデータをセットする (表示はまだしない)
        SetData        = {
            param(
                [EntryBase[]]$items
            )
            $gridref.Tag.Items = @($items)
        }.GetNewClosure()

        # [メソッド2] 現在のデータと、引数の履歴を基に、グリッド表示を更新する
        RefreshView    = {
            param(
                [EntryBase[]]$history = @()
            )

            $results = $gridref.Tag.Items

            foreach ($r in $results) {
                $isMatch = $false
                if ($null -ne $history) {
                    foreach ($h in $history) {
                        if ($h.Equals($r)) { $isMatch = $true; break }
                    }
                }
                # 既存のプロパティを上書きするために -Force を付ける
                $r | Add-Member -NotePropertyName _IsHistoryMatch -NotePropertyValue $isMatch -Force
            }
            $sorted = $results | Sort-Object { -not $_._IsHistoryMatch }          
            $gridref.ItemsSource = $sorted
        }.GetNewClosure()
        
        # [メソッド3] グリッドをクリアする
        Clear          = {
            $gridref.Tag.Items = @()
            $gridref.ItemsSource = $null
        }.GetNewClosure()

        # 外部から差し替え可能な Selected イベント用スクリプトブロック
        Selected       = { param($entry) Write-Host "Tag.Selected: $($entry.ToString())" }
    }

    # --- イベントハンドラ (変更なし) ---

    # 履歴一致行を色付け
    $grid.Add_LoadingRow({
            param($sender, $e)
            # 参照先を $item._IsHistoryMatch に修正 (元々正しかったが明記)
            $item = $e.Row.Item
            if ($item -and $item._IsHistoryMatch) { $e.Row.Background = $sender.Tag.HighlightBrush }
            else { $e.Row.Background = $null } # 色をリセットする処理も追加
        })

    # 選択イベント
    $grid.Add_SelectionChanged({
            param($sender, $e)
        
            # 以前選択されていた行の色をリセット
            foreach ($removedItem in $e.RemovedItems) {
                $row = $sender.ItemContainerGenerator.ContainerFromItem($removedItem)
                if ($row -is [Windows.Controls.DataGridRow]) {
                    # 履歴にマッチしていれば黄色、そうでなければデフォルト色
                    $row.Background = if ($removedItem._IsHistoryMatch) { $sender.Tag.HighlightBrush } else { $null }
                }
            }

            # 新しく選択された行を処理
            $selected = $sender.SelectedItem
            if ($selected) {
                $row = $sender.ItemContainerGenerator.ContainerFromItem($selected)
                if ($row -is [Windows.Controls.DataGridRow]) { $row.Background = $sender.Tag.SelectionBrush }

                # 外部スクリプト呼び出し
                # & 演算子を使うことで、引数問題を気にせず堅牢に呼び出せる
                & $sender.Tag.Selected $selected
            }
        })

    return $grid
}
