function Init-ResultGridLogic {
    param(
        [System.Windows.Controls.DataGrid]$control,
        [string]$Name,
        [Action[string, string, string]]$SetStatus = $null
    )

    if (-not $SetStatus) {
        $SetStatus = [Action[string, string, string]] {
            param($level, $component, $message)
            Write-Host "[$level][$component] $message"
        }
    }

    # --- 基本設定 ---
    $control.AutoGenerateColumns = $true
    $control.IsReadOnly = $true
    $control.SelectionMode = "Single"
    $control.SelectionUnit = "FullRow"

    $control.Tag = @{
        Component      = $Name
        Items          = @()

        SetStatus      = [Action[string,string]] {
            param($level,$message)
            $SetStatus.Invoke($level,$control.Tag.Component,$message)
        }.GetNewClosure()

        # --- データセット（触らない） ---
        SetData        = {
            param([EntryBase[]]$items)
            if ($items) {
                $control.Tag.Items = ,$items
            } else {
                $control.Tag.Items = @()
            }
        }.GetNewClosure()

        # --- 履歴突合せ＋並び替え ---
        RefreshView    = {
            param([EntryBase[]]$history = @())

            $results = $control.Tag.Items
            foreach ($r in $results) {
                $isMatch = $false
                foreach ($h in $history) {
                    if ($h.Equals($r)) { $isMatch = $true; break }
                }
                $r | Add-Member -NotePropertyName _IsHistoryMatch -NotePropertyValue $isMatch -Force
            }

            $sorted = $results | Sort-Object { -not $_._IsHistoryMatch }
            $control.ItemsSource = $sorted
        }.GetNewClosure()

        Clear          = {
            $control.Tag.Items = @()
            $control.ItemsSource = $null
        }.GetNewClosure()

        Selected       = {
            param($entry)
            $control.Tag.SetStatus.Invoke("Info","選択: $($entry.名称) [$($entry.住所)]")
        }.GetNewClosure()
    }

    # --- "_" 始まりの列は表示しない（イベントで除外） ---
    $control.Add_AutoGeneratingColumn({
        param($sender, $e)
        if ($e.PropertyName -match '^_') { $e.Cancel = $true }
    })

    # --- 選択イベント（通知のみ、色付けはXAMLに寄せる） ---
    $control.Add_SelectionChanged({
        param($sender, $e)
        $selected = $sender.SelectedItem
        if ($selected) {
            & $sender.Tag.Selected $selected
        }
    })
}