Add-Type -AssemblyName PresentationFramework

function New-AutoCompleteComboBox {
    param([string]$Name)

    # 履歴ロード
    $HistoryFile = "history_$Name.json"
    $history = @()
    if (Test-Path $HistoryFile) {
        try { $history = Get-Content $HistoryFile -Raw | ConvertFrom-Json } catch { $history = @() }
    }

    # コンボ生成
    $comboBox = New-Object System.Windows.Controls.ComboBox
    $comboBox.IsEditable = $true
    $comboBox.Margin = "10"
    $comboBox.FontSize = 16

    # ItemsSourceは常にList[string]で渡す
    $initialItems = New-Object System.Collections.Generic.List[string]
    foreach ($h in $history) { if ($h.keyword) { $initialItems.Add([string]$h.keyword) } }
    $comboBox.ItemsSource = $initialItems

    # Tagに状態を保持
    $comboBox.Tag = @{
        HistoryFile = $HistoryFile
        History     = $history
    }

    # 入力補完（TextChangedはsender: ComboBox）
    $comboBox.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
        [System.Windows.Controls.TextChangedEventHandler] {
            param($cb)
            $current = [string]$cb.Text
            $hist = $cb.Tag.History

            if ($current.Length -gt 0) {
                $startsWith = $hist | Where-Object { $_.keyword -and ([string]$_.keyword).StartsWith($current) }
                $contains   = $hist | Where-Object { $_.keyword -and ([string]$_.keyword) -like "*$current*" -and -not ([string]$_.keyword).StartsWith($current) }
                $matches    = @($startsWith) + @($contains)

                if ($matches.Count -gt 0) {
                    $items = New-Object System.Collections.Generic.List[string]
                    foreach ($m in $matches) { if ($m.keyword) { $items.Add([string]$m.keyword) } }
                    $cb.ItemsSource = $items
                    $cb.IsDropDownOpen = $true
                }
                else {
                    $cb.ItemsSource = (New-Object System.Collections.Generic.List[string])
                    $cb.IsDropDownOpen = $false
                }
            }
            else {
                # 空入力時は履歴全体を提示（閉じたまま）
                $items = New-Object System.Collections.Generic.List[string]
                foreach ($m in $hist) { if ($m.keyword) { $items.Add([string]$m.keyword) } }
                $cb.ItemsSource = $items
                $cb.IsDropDownOpen = $false
            }
        }
    )

    # キー操作（Enter専用を置き換え → 矢印＋Tab＋Enter統合）
    $comboBox.Add_Loaded({
        param($sender, $args)

        $sender.ApplyTemplate()
        $editable = $sender.Template.FindName("PART_EditableTextBox", $sender)

        if (-not $editable) {
            # レンダ後にもう一度試す（Dispatcherで遅延）
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeAsync({
                $sender.ApplyTemplate()
                $editable2 = $sender.Template.FindName("PART_EditableTextBox", $sender)
                if ($editable2) {
                    $editable2.Add_KeyDown({
                        param($sender,$args)
                        switch ($args.Key) {
                            "Down" {
                                if ($sender.Items.Count -gt 0) {
                                    $sender.IsDropDownOpen = $true
                                    $sender.Focus()
                                    $sender.SelectedIndex = 0
                                    $args.Handled = $true
                                }
                            }
                            "Up" {
                                if ($sender.IsDropDownOpen -and $sender.Items.Count -gt 0) {
                                    $sender.Focus()
                                    $args.Handled = $true
                                }
                            }
                            "Tab" {
                                if ($sender.IsDropDownOpen -and $sender.SelectedItem) {
                                    $sender.Text = $sender.SelectedItem
                                    $sender.IsDropDownOpen = $false
                                    $args.Handled = $true
                                }
                            }
                            "Enter" {
                                $sender.IsDropDownOpen = $false
                                $args.Handled = $true
                                # 検索は外側が $sender.Text を使って実行する前提
                            }
                        }
                    })
                }
            }) | Out-Null
        }
        else {
            $editable.Add_KeyDown({
                $keyEvent = $_
                switch ($_.Key) {
                    "Down" {
                        if ($this.Items.Count -gt 0) {
                            $this.IsDropDownOpen = $true
                            $this.Focus()
                            $this.SelectedIndex = 0
                            $keyEvent.Handled = $true
                        }
                    }
                    "Up" {
                        if ($this.IsDropDownOpen -and $this.Items.Count -gt 0) {
                            $this.Focus()
                            $keyEvent.Handled = $true
                        }
                    }
                    "Tab" {
                        if ($this.IsDropDownOpen -and $this.SelectedItem) {
                            $this.Text = $this.SelectedItem
                            $this.IsDropDownOpen = $false
                            $keyEvent.Handled = $true
                        }
                    }
                    "Enter" {
                        $this.IsDropDownOpen = $false
                        $keyEvent.Handled = $true
                        # 検索は外側が $sender.Text を使って実行する前提
                    }
                }
            })
        }
    })

    # 履歴追加（重複排除＋lastUsed更新＋最新順）
        $comboBox.Tag.AddHistory = {
        param([System.Windows.Controls.ComboBox]$cb, [psobject]$Entry)

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

        # 最新利用日でソート
        $hist = $hist | Sort-Object { [datetime]$_.lastUsed } -Descending

        # 保存
        $hist | ConvertTo-Json -Depth 5 | Out-File $hf -Encoding UTF8

        # 候補リフレッシュ（List[string]を再構築）
        $items = New-Object System.Collections.Generic.List[string]
        foreach ($h in $hist) { if ($h.keyword) { $items.Add([string]$h.keyword) } }
        $cb.ItemsSource = $items

        # Tag更新
        $cb.Tag.History = $hist
    }

    return $comboBox
}