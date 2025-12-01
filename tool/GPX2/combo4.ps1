function Add-HistoryEntry {
    param(
        [System.Windows.Controls.ComboBox]$cb,
        [psobject]$Entry
    )

    Write-Host "Add-History called for keyword=$($Entry.keyword)"

    $hf = $cb.Tag.HistoryFile
    $hist = $cb.Tag.History

    $item = $hist | Where-Object { $_.keyword -eq $Entry.keyword }
    if ($item) {
        foreach ($point in $Entry.selected) {
            $exists = $item.selected | Where-Object { $_.lat -eq $point.lat -and $_.lon -eq $point.lon }
            if (-not $exists) { $item.selected += $point }
        }
        $item.lastUsed = (Get-Date).ToString("s")
    }
    else {
        $Entry | Add-Member -NotePropertyName lastUsed -NotePropertyValue (Get-Date).ToString("s")
        $hist += $Entry
    }

    $hist = $hist | Sort-Object { [datetime]$_.lastUsed } -Descending
    $hist | ConvertTo-Json -Depth 5 | Out-File $hf -Encoding UTF8

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($h in $hist) { if ($h.keyword) { $items.Add([string]$h.keyword) } }
    $cb.ItemsSource = $items

    $cb.Tag.History = $hist
}
function New-SearchCombo {
    param([string]$Name)

    $comboBox = New-Object System.Windows.Controls.ComboBox
    $comboBox.IsEditable = $true
    $comboBox.Margin = "5"
    $comboBox.FontSize = 16

    # 履歴ファイルと初期履歴
    $HistoryFile = "history_$Name.json"
    $history = @()
    if (Test-Path $HistoryFile) {
        try { $history = Get-Content $HistoryFile -Raw | ConvertFrom-Json } catch { $history = @() }
    }

    $initialItems = New-Object System.Collections.Generic.List[string]
    foreach ($h in $history) { if ($h.keyword) { $initialItems.Add([string]$h.keyword) } }
    $comboBox.ItemsSource = $initialItems

    # Tagに状態と処理をまとめる
    $cbRef = $comboBox
    $comboBox.Tag = @{
        HistoryFile = $HistoryFile
        History     = $history

        Entered     = [Action[string]] {
            param($kw)
            Write-Host "Tag.Entered: $kw"
        }

        AddHistory  = {
            param($Entry)
            Add-HistoryEntry -cb $cbRef -Entry $Entry
        }.GetNewClosure()
    }

    # Loaded → 内部 TextBox の KeyDown をフック
    $comboBox.Add_Loaded({
            param($sender, $args)
            $sender.ApplyTemplate()
            $editable = $sender.Template.FindName("PART_EditableTextBox", $sender)
            if (-not $editable) { return }

            $editable.Add_KeyDown({
                    $e = $_
                    $textBox = $this
                    $comboRef = [System.Windows.Controls.ComboBox]$textBox.TemplatedParent
                    if (-not $comboRef) { return }

                    switch ($e.Key) {
                        "Return" {
                            $comboRef.IsDropDownOpen = $false
                            $e.Handled = $true
                            Write-Host "Enter → close"
                            # 履歴更新と外部処理呼び出し
#                            $comboRef.Tag.AddHistory.Invoke(@{ keyword = $comboRef.Text; selected = @() })
                            $comboRef.Tag.Entered.Invoke($comboRef.Text)
                        }
                    }
                })
        })

    # SelectionChanged → AddHistory + Entered
    $comboBox.Add_SelectionChanged({
            param($sender, $args)
            if ($sender.SelectedItem) {
                $keyword = [string]$sender.SelectedItem
                Write-Host "Selection → Tag.Entered: $keyword"
#                $sender.Tag.AddHistory.Invoke(@{ keyword = $keyword; selected = @() })
                $sender.Tag.Entered.Invoke($keyword)
            }
        })

    return $comboBox
}

Add-Type -AssemblyName PresentationFramework

# ComboBox を生成
$combo = New-SearchCombo -Name "search"

# 外部処理を差し替え（テスト用）
$combo.Tag.Entered = {
    param($kw)
    Write-Host "外部処理 (Entered): $kw"
}

# ウィンドウを作成
$window = New-Object System.Windows.Window
$window.Title = "SearchCombo Test"
$window.Width = 400
$window.Height = 200

# StackPanel に配置
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Children.Add($combo)
$window.Content = $panel

# 表示
$window.ShowDialog() | Out-Null