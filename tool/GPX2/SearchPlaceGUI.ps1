function Load-History {
    param([string]$HistoryFile)

    if (Test-Path $HistoryFile) {
        try { return Get-Content $HistoryFile -Raw | ConvertFrom-Json }
        catch { return @() }
    }
    return @()
}

function Save-History {
    param([string]$HistoryFile, [array]$History)

    $History | ConvertTo-Json -Depth 5 | Out-File $HistoryFile -Encoding UTF8
}

function Convert-History {
    param([array]$History)

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($h in $History) {
        if ($h.keyword) { $items.Add([string]$h.keyword) }
    }
    return $items
}

function Add-History {
    param([array]$History, [psobject]$Entry)

    $item = $History | Where-Object { $_.keyword -eq $Entry.keyword }
    if ($item) {
        foreach ($point in $Entry.selected) {
            $exists = $item.selected | Where-Object { $_.lat -eq $point.lat -and $_.lon -eq $point.lon }
            if (-not $exists) { $item.selected += $point }
        }
        $item.lastUsed = (Get-Date).ToString("s")
    }
    else {
        $Entry | Add-Member -NotePropertyName lastUsed -NotePropertyValue (Get-Date).ToString("s")
        $History += $Entry
    }

    return $History | Sort-Object { [datetime]$_.lastUsed } -Descending
}

function Add-HistoryEntry {
    param(
        [System.Windows.Controls.ComboBox]$cb,
        [psobject]$Entry
    )

    Write-Host "Add-HistoryEntry called for keyword=$($Entry.keyword)"

    $hf   = $cb.Tag.HistoryFile
    $hist = $cb.Tag.History

    # 更新処理
    $hist = Add-History -History $hist -Entry $Entry

    # 保存
    Save-History -HistoryFile $hf -History $hist

    # リスト更新
    $cb.ItemsSource = Convert-History $hist

    # Tag更新
    $cb.Tag.History = $hist
}
function New-SearchCombo {
    param([string]$Name)

    $comboBox = New-Object System.Windows.Controls.ComboBox
    $comboBox.IsEditable = $true
    $comboBox.IsTextSearchEnabled = $false   # ← 自動選択を無効化
    $comboBox.Margin     = "5"
    $comboBox.FontSize   = 16

    # 履歴ファイルと初期履歴
    $HistoryFile = "history_$Name.json"
    $history     = Load-History -HistoryFile $HistoryFile
    $comboBox.ItemsSource = Convert-History -History $history

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
                    $comboRef.Tag.Entered.Invoke($comboRef.Text)
                }
                "Tab" {
                    $comboRef.IsDropDownOpen = $false
                    $e.Handled = $true
                    Write-Host "Tab → move focus"
                    $comboRef.Tag.Entered.Invoke($comboRef.Text)
                }
                "Down" {
                    if (-not $comboRef.IsDropDownOpen) {
                        $comboRef.IsDropDownOpen = $true
                        $e.Handled = $true
                        Write-Host "Down → open dropdown"
                    }
                }
            }
        })
    })

    # SelectionChanged → ドロップダウン操作時のみ Entered
    $comboBox.Add_SelectionChanged({
        param($sender, $args)
        if ($sender.IsDropDownOpen -and $sender.SelectedItem) {
            $keyword = [string]$sender.SelectedItem
            Write-Host "Selection → Tag.Entered: $keyword"
            $sender.Tag.Entered.Invoke($keyword)
        }
    })

    return $comboBox
}