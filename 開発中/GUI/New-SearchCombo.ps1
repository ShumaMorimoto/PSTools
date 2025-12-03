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
function Compare-PsObject {
    param(
        [psobject]$a,
        [psobject]$b
    )
    # JSON化して全プロパティ一致を判定
    return ((ConvertTo-Json $a -Compress) -eq (ConvertTo-Json $b -Compress))
}
function Add-History {
    param(
        [System.Windows.Controls.ComboBox]$cb,
        [psobject]$Entry   # { keyword="函館駅"; selected=@{ lon=..; lat=..; name="函館駅" } }
    )

    Write-Host "Add-History called for keyword=$($Entry.keyword)"

    $hf = $cb.Tag.HistoryFile
    $hist = @($cb.Tag.History)

    # keyword一致する履歴を探す
    $item = $hist | Where-Object { $_.keyword -eq $Entry.keyword }

    if ($item) {
        # selected を List に変換
        if (-not ($item.selected -is [System.Collections.Generic.List[object]])) {
            $list = New-Object System.Collections.Generic.List[object]
            foreach ($p in $item.selected) { $list.Add($p) }
            $item.selected = $list
        }

        $point = $Entry.selected

        # === 汎用的な重複チェック ===
        $exists = $false
        foreach ($s in $item.selected) {
            if (Compare-PsObject $s $point) { $exists = $true; break }
        }

        if (-not $exists) {
            $item.selected.Add($point)
            Write-Host "拠点追加: $($point | ConvertTo-Json -Compress)"
        }
        else {
            Write-Host "既存拠点のため追加せず"
        }

        $item.lastUsed = (Get-Date).ToString("s")
    }
    else {
        # 新規エントリ
        $list = New-Object System.Collections.Generic.List[object]
        $list.Add($Entry.selected)
        $Entry.selected = $list
        $Entry | Add-Member -NotePropertyName lastUsed -NotePropertyValue (Get-Date).ToString("s")
        $hist += $Entry
    }

    # 更新・保存
    $hist = $hist | Sort-Object { [datetime]$_.lastUsed } -Descending
    $hist | ConvertTo-Json -Depth 5 | Out-File $hf -Encoding UTF8

    # ComboBox の ItemsSource 更新
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($h in $hist) { if ($h.keyword) { $items.Add([string]$h.keyword) } }
    $cb.ItemsSource = $items
    $cb.Tag.History = $hist
}
function Get-History {
    param(
        [System.Windows.Controls.ComboBox]$cb,
        [string]$Keyword
    )
    $cb.Tag.History | Where-Object { $_.keyword -eq $Keyword }
}

function New-SearchCombo {
    param(
        [string]$Name,
        [string]$HistoryName = $null   # 履歴共有用の名前（オプション）
    )

    $comboBox = New-Object System.Windows.Controls.ComboBox
    $comboBox.IsEditable = $true
    $comboBox.IsTextSearchEnabled = $false
    $comboBox.Margin = "5"
    $comboBox.FontSize = 16

    # 履歴ファイル名の決定
    if ([string]::IsNullOrWhiteSpace($HistoryName)) {
        $HistoryFile = "history_$Name.json"
    }
    else {
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
            Add-History -cb $cbRef -Entry $Entry
        }.GetNewClosure()

        GetHistory  = {
            param($Keyword)
            Get-History -cb $cbRef -Keyword $Keyword
        }.GetNewClosure()
    }

    # Loaded → 内部 TextBox の TextChanged / KeyDown をフック
    $comboBox.Add_Loaded({
            $this.ApplyTemplate()
            $editable = $this.Template.FindName("PART_EditableTextBox", $this)
            if (-not $editable) { return }

            # TextChanged → 入力修正のたびにリスト再生成
            $editable.Add_TextChanged({
                    $comboRef = $this.TemplatedParent
                    $comboRef.ItemsSource = Convert-History -History $comboRef.Tag.History -Keyword $comboRef.Text
                    $comboRef.SelectedIndex = -1
                    Write-Host "TextChanged(PART_EditableTextBox) → リスト再生成"
                })

            # KeyDown制御（TAB/Enter）
            $editable.Add_KeyDown({
                    $e = $_
                    $comboRef = $this.TemplatedParent

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
                    if (-not $this.IsDropDownOpen) {
                        $this.IsDropDownOpen = $true
                        $this.SelectedIndex = 0
                        $e.Handled = $true
                        Write-Host "ComboBox.Down → ドロップダウンを開いて先頭選択"
                    }
                }
            }
        })

    # SelectionChanged → Textにコピーのみ
    #    $comboBox.Add_SelectionChanged({
    #            if ($this.SelectedItem) {
    #                $this.Text = [string]$this.SelectedItem
    #                Write-Host "候補選択 → Textにコピー"
    #            }
    #        })

    return $comboBox
}