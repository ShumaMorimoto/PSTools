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

function New-SearchCombo {
    param([string]$Name, [string]$HistoryName = $null)

    $comboBox = New-Object System.Windows.Controls.ComboBox
    $comboBox.IsEditable = $true
    $comboBox.IsTextSearchEnabled = $false
    $comboBox.Margin = "5"
    $comboBox.FontSize = 16

    # APPDATA\GUITools\data フォルダを基準にする
    $baseDir = Join-Path $env:APPDATA "GUITools\data"
    if (-not (Test-Path $baseDir)) {
        New-Item -ItemType Directory -Path $baseDir | Out-Null
    }

    $HistoryFile = if ([string]::IsNullOrWhiteSpace($HistoryName)) {
        Join-Path $baseDir "history_$Name.json"
    }
    else {
        Join-Path $baseDir "history_$HistoryName.json"
    }
    
    $cbRef = $comboBox
    $comboBox.Tag = @{
        HistoryFile         = $HistoryFile
        History             = @()
        EntryClass          = [EntryBase]  # 外から差し替え可能

        LoadHistory         = { Load-History $cbRef }.GetNewClosure()
        SaveHistory         = { Save-History $cbRef }.GetNewClosure()
        RefreshList         = { param($Keyword) Refresh-List -cb $cbRef -Keyword $Keyword }.GetNewClosure()
        AddHistory          = { param($Keyword, $Entry) Add-History -cb $cbRef -Keyword $Keyword -Entry $Entry }.GetNewClosure()
        GetHistory          = { param($Keyword) Get-History -cb $cbRef -Keyword $Keyword }.GetNewClosure()

        Entered             = [Action[string]] { param($kw) Write-Host "Tag.Entered: $kw" }

        # テキストボックス確定後の KeyUp(Return) を抑制するフラグ
        SkipNextKeyUpReturn = $false
    }

    # Loadedイベント（内部TextBoxアクセス）
    $comboBox.Add_Loaded({
            param($sender, $e)
            $sender.ApplyTemplate()
            $editable = $sender.Template.FindName("PART_EditableTextBox", $sender)
            if (-not $editable) { return }

            # KeyUp: 文字入力時のリスト更新 + IME確定時(KeyUp:Return)の扱い
            $editable.Add_KeyUp({
                    param($sender, $e)
                    $comboRef = $sender.TemplatedParent
                    # IME確定時は KeyUp(Return) が来るが、テキストボックス確定直後なら抑制
                    if ($e.Key -eq "Return") {
                        if ($comboRef.Tag.SkipNextKeyUpReturn) {
                            $comboRef.Tag.SkipNextKeyUpReturn = $false
                            return  # テキストボックス確定に伴う KeyUp(Return) は無視
                        }
                        # IME側の確定（KeyUpのみ）で来た Return はリフレッシュする
                        $comboRef.Tag.RefreshList.Invoke($comboRef.Text)
                        $comboRef.SelectedIndex = -1
                        return
                    }
                })

            $editable.Add_KeyDown({
                    param($sender, $e)
                    $comboRef = $sender.TemplatedParent
                    switch ($e.Key) {
                        "Return" {
                            # テキストボックスでの検索確定：直後の KeyUp(Return) は抑制
                            $comboRef.Tag.SkipNextKeyUpReturn = $true
                            $e.Handled = $true
                            $comboRef.IsDropDownOpen = $false
                            $comboRef.Tag.Entered.Invoke($comboRef.Text)
                        }
                    }
                })

            # 履歴ロードは Loaded 時のみ呼ぶ
            $sender.Tag.LoadHistory.Invoke()
            $sender.Tag.RefreshList.Invoke("")
        })

    # ComboBox の SelectionChangedイベント
    $comboBox.Add_SelectionChanged({
            param($sender, $e)
            if ($sender.SelectedItem) {
                $sender.Tag.Entered.Invoke($sender.SelectedItem)
            }
        })

    return $comboBox
}