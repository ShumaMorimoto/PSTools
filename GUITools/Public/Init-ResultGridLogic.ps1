function Init-ResultGridLogic {
    param(
        [System.Windows.Controls.DataGrid]$control,     # ← 統一して control
        [string]$Name,
        [Action[string, string, string]]$SetStatus = $null
    )

    if (-not $SetStatus) {
        # デフォルト実装: 標準出力のみ
        $SetStatus = [Action[string, string, string]] {
            param($level, $component, $message)
            $prefix = "[$level][$component]"
            Write-Host "$prefix $message"
        }
    }

    # --- 基本設定（編集不可に統一） ---
    $control.AutoGenerateColumns = $true   # 結果は自動列生成でよい
    $control.IsReadOnly = $true   # 編集不可にする
    $control.SelectionMode = "Extended"
    $control.SelectionUnit = "FullRow"

    $control.Tag = @{
        Component      = $Name
        Items          = @()
        HighlightBrush = [System.Windows.Media.Brushes]::LightYellow
        SelectionBrush = [System.Windows.Media.Brushes]::LightGreen
        SetStatus      = $SetStatus

        SetData        = {
            param([EntryBase[]]$items)
            if ($items) {
                $control.Tag.Items = , $items
            }
            else {
                $control.Tag.Items = @()
            }

        }.GetNewClosure()

        RefreshView    = {
            param([EntryBase[]]$history = @())
            $results = $control.Tag.Items
            foreach ($r in $results) {
                $isMatch = $false
                if ($null -ne $history) {
                    foreach ($h in $history) {
                        if ($h.Equals($r)) { $isMatch = $true; break }
                    }
                }
                $r | Add-Member -NotePropertyName _IsHistoryMatch -NotePropertyValue $isMatch -Force
            }
            $sorted = @()
            $sorted += $results | Sort-Object { -not $_._IsHistoryMatch }
            $control.ItemsSource = $sorted
        }.GetNewClosure()

        Clear          = {
            $control.Tag.Items = @()
            $control.ItemsSource = $null
        }.GetNewClosure()

        Selected       = {
            param($entry)
            $control.Tag.SetStatus.Invoke("Info", $control.Tag.Component, "選択: $($entry.ToString())")
        }.GetNewClosure()
    }

    # "_" 始まりの列は表示しない
    $control.Add_AutoGeneratingColumn({
            param($sender, $e)
            if ($e.PropertyName -match '^_') { $e.Cancel = $true }
        })

    # 履歴一致行を色付け
    $control.Add_LoadingRow({
            param($sender, $e)
            $item = $e.Row.Item
            if ($item -and $item._IsHistoryMatch) { $e.Row.Background = $sender.Tag.HighlightBrush }
            else { $e.Row.Background = $null }
        })

    # 選択イベント
    $control.Add_SelectionChanged({
            param($sender, $e)
            foreach ($removedItem in $e.RemovedItems) {
                $row = $sender.ItemContainerGenerator.ContainerFromItem($removedItem)
                if ($row -is [System.Windows.Controls.DataGridRow]) {
                    $row.Background = if ($removedItem._IsHistoryMatch) { $sender.Tag.HighlightBrush } else { $null }
                }
            }
            $selected = $sender.SelectedItem
            if ($selected) {
                $row = $sender.ItemContainerGenerator.ContainerFromItem($selected)
                if ($row -is [System.Windows.Controls.DataGridRow]) { $row.Background = $sender.Tag.SelectionBrush }
                & $sender.Tag.Selected $selected
            }
        })
}