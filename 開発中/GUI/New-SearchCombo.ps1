Add-Type -AssemblyName PresentationFramework

# ================================
# 履歴操作関数群
# ================================
function Load-History {
    param([System.Windows.Controls.ComboBox]$cb)

    $file = $cb.Tag.HistoryFile
    $entries = @()
    if (Test-Path $file) {
        try {
            $json = Get-Content $file -Raw | ConvertFrom-Json
            foreach ($o in $json) {
                $cls = $cb.Tag.EntryClass
                $selected = [System.Collections.Generic.List[object]]::new()
                foreach ($s in $o.Selected) {
                    $selected.Add($cls::FromJson($s))
                }
                $entries += @{
                    Keyword  = $o.Keyword
                    Selected = $selected
                    lastUsed = $o.lastUsed
                }
            }
        }
        catch { $entries = @() }
    }
    # return せずに直接設定
    $cb.Tag.History = $entries
}

function Save-History {
    param([System.Windows.Controls.ComboBox]$cb)

    $file = $cb.Tag.HistoryFile
    $hist = $cb.Tag.History

    $jsonList = @()
    foreach ($h in $hist) {
        $selectedJson = @()
        foreach ($s in $h.Selected) {
            # Entryオブジェクトをハッシュ化して保存
            $selectedJson += @{ Code = $s.Code; Name = $s.Name }
        }
        $jsonList += @{
            Keyword  = $h.Keyword
            Selected = $selectedJson
            lastUsed = $h.lastUsed
        }
    }

    $jsonList | ConvertTo-Json -Depth 10 -Compress | Out-File $file -Encoding UTF8
}

function Refresh-List {
    param([System.Windows.Controls.ComboBox]$cb, [string]$Keyword = "")
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($h in $cb.Tag.History) {
        $kw = $h.Keyword
        if ($kw) {
            if ([string]::IsNullOrWhiteSpace($Keyword) -or $kw -like "$Keyword*" -or $kw -like "*$Keyword*") {
                $items.Add($kw)
            }
        }
    }
    $cb.ItemsSource = $items
}

function Add-History {
    param([System.Windows.Controls.ComboBox]$cb, [string]$Keyword, [object]$Entry)
    $hist = @($cb.Tag.History)
    $item = $hist | Where-Object { $_.Keyword -eq $Keyword }
    if ($item) {
        $exists = $false
        foreach ($s in $item.Selected) { if ($s.Equals($Entry)) { $exists = $true; break } }
        if (-not $exists) { $item.Selected.Add($Entry) }
        $item.lastUsed = (Get-Date).ToString("s")
    }
    else {
        $newItem = @{ Keyword = $Keyword; Selected = [System.Collections.Generic.List[object]]::new(); lastUsed = (Get-Date).ToString("s") }
        $newItem.Selected.Add($Entry)
        $hist += $newItem
    }
    $cb.Tag.History = $hist | Sort-Object { [datetime]$_.lastUsed } -Descending
    Save-History $cb
    Refresh-List -cb $cb
}

function Get-History {
    param([System.Windows.Controls.ComboBox]$cb, [string]$Keyword)
    $cb.Tag.History | Where-Object { $_.Keyword -eq $Keyword }
}

# ================================
# 検索用 ComboBox（削らず完全版）
# ================================
function New-SearchCombo {
    param([string]$Name, [string]$HistoryName = $null)

    $comboBox = New-Object System.Windows.Controls.ComboBox
    $comboBox.IsEditable = $true
    $comboBox.IsTextSearchEnabled = $false
    $comboBox.Margin = "5"
    $comboBox.FontSize = 16

    $HistoryFile = if ([string]::IsNullOrWhiteSpace($HistoryName)) { "history_$Name.json" } else { "history_$HistoryName.json" }

    $cbRef = $comboBox
    $comboBox.Tag = @{
        HistoryFile = $HistoryFile
        History     = @()
        EntryClass  = [EntryBase]  # 外から差し替え可能

        LoadHistory = { Load-History $cbRef }.GetNewClosure()
        SaveHistory = { Save-History $cbRef }.GetNewClosure()
        RefreshList = { param($Keyword) Refresh-List -cb $cbRef -Keyword $Keyword }.GetNewClosure()
        AddHistory  = { param($Keyword, $Entry) Add-History -cb $cbRef -Keyword $Keyword -Entry $Entry }.GetNewClosure()
        GetHistory  = { param($Keyword) Get-History -cb $cbRef -Keyword $Keyword }.GetNewClosure()

        Entered     = [Action[string]] { param($kw) Write-Host "Tag.Entered: $kw" }
    }

    $comboBox.Tag.LoadHistory.Invoke()
    $comboBox.Tag.RefreshList.Invoke("")

    # Loadedイベント（内部TextBoxアクセス）
    $comboBox.Add_Loaded({
            param($sender, $e)
            $sender.ApplyTemplate()
            $editable = $sender.Template.FindName("PART_EditableTextBox", $sender)
            if (-not $editable) { return }

            $editable.Add_TextChanged({
                    param($sender, $e)
                    $comboRef = $sender.TemplatedParent
                    $comboRef.Tag.RefreshList.Invoke($comboRef.Text)
                    $comboRef.SelectedIndex = -1
                })

            $editable.Add_KeyDown({
                    param($sender, $e)
                    $comboRef = $sender.TemplatedParent
                    switch ($e.Key) {
                        "Tab" {
                            $e.Handled = $true
                            $comboRef.IsDropDownOpen = -not $comboRef.IsDropDownOpen
                            if ($comboRef.IsDropDownOpen) { $comboRef.SelectedIndex = 0 }
                        }
                        "Return" {
                            $e.Handled = $true
                            $comboRef.IsDropDownOpen = $false
                            $comboRef.Tag.Entered.Invoke($comboRef.Text)
                        }
                    }
                })
        })

    # ComboBox 自体の KeyDownイベント
    $comboBox.Add_KeyDown({
            param($sender, $e)
            if ($e.Key -eq "Down" -and -not $sender.IsDropDownOpen) {
                $sender.IsDropDownOpen = $true
                $sender.SelectedIndex = 0
                $e.Handled = $true
            }
        })

    return $comboBox
}
