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