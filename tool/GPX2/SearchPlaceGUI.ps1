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
    param(
        [array]$History,
        [string]$Keyword = ""
    )
    $items = New-Object System.Collections.Generic.List[string]

    foreach ($h in $History) {
        if ($h.keyword) {
            if ([string]::IsNullOrWhiteSpace($Keyword)) {
                # キーワードが空なら全件
                $items.Add([string]$h.keyword)
            }
            else {
                # 前方一致 or 部分一致
                if ($h.keyword -like "$Keyword*" -or $h.keyword -like "*$Keyword*") {
                    $items.Add([string]$h.keyword)
                }
            }
        }
    }
    # 1件でも必ず配列として返す
    return , $items
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

function New-SearchCombo {
    param(
        [string]$Name,
        [string]$HistoryName = $null   # 履歴共有用の名前（オプション）
    )

    $comboBox = New-Object System.Windows.Controls.ComboBox
    $comboBox.IsEditable = $true
    $comboBox.IsTextSearchEnabled = $false
    $comboBox.Margin     = "5"
    $comboBox.FontSize   = 16

    # 履歴ファイル名の決定
    if ([string]::IsNullOrWhiteSpace($HistoryName)) {
        $HistoryFile = "history_$Name.json"
    } else {
        $HistoryFile = "history_$HistoryName.json"
    }

    # 履歴のロード
    $history = Load-History -HistoryFile $HistoryFile
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

    # Loaded → 内部 TextBox の TextChanged / KeyDown をフック
    $comboBox.Add_Loaded({
        param($sender, $args)
        $sender.ApplyTemplate()
        $editable = $sender.Template.FindName("PART_EditableTextBox", $sender)
        if (-not $editable) { return }

        # TextChanged → 入力修正のたびにリスト再生成
        $editable.Add_TextChanged({
            param($tbSender, $tbArgs)
            $comboRef = [System.Windows.Controls.ComboBox]$tbSender.TemplatedParent
            $comboRef.ItemsSource = Convert-History -History $comboRef.Tag.History -Keyword $comboRef.Text
            $comboRef.SelectedIndex = -1
            Write-Host "TextChanged(PART_EditableTextBox) → リスト再生成"
        })

        # KeyDown制御（TAB/Enter）
        $editable.Add_KeyDown({
            $e = $_
            $comboRef = [System.Windows.Controls.ComboBox]$this.TemplatedParent
            if (-not $comboRef) { return }

            switch ($e.Key) {
                "Tab" {
                    $e.Handled = $true
                    if (-not $comboRef.IsDropDownOpen) {
                        $comboRef.IsDropDownOpen = $true
                        $comboRef.SelectedIndex = 0
                    }
                    else {
                        $comboRef.SelectedIndex = ($comboRef.SelectedIndex + 1) % $comboRef.Items.Count
                    }
                }
                "Return" {
                    $e.Handled = $true
                    $comboRef.IsDropDownOpen = $false
                    $comboRef.Tag.Entered.Invoke($comboRef.Text)
                }
            }
        })
    })

    # ComboBox側でDownキーを処理
    $comboBox.Add_KeyDown({
        $e = $_
        switch ($e.Key) {
            "Down" {
                if (-not $comboBox.IsDropDownOpen) {
                    $comboBox.IsDropDownOpen = $true
                    $comboBox.SelectedIndex = 0
                    $e.Handled = $true
                    Write-Host "ComboBox.Down → ドロップダウンを開いて先頭選択"
                }
            }
        }
    })

    # SelectionChanged → Textにコピーのみ
    $comboBox.Add_SelectionChanged({
        if ($comboBox.IsDropDownOpen -and $comboBox.SelectedItem) {
            $comboBox.Text = [string]$comboBox.SelectedItem
            Write-Host "候補選択 → Textにコピー"
        }
    })

    return $comboBox
}