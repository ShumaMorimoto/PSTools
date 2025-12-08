function Init-SearchComboLogic {
    param(
        [System.Windows.Controls.ComboBox]$control,
        [string]$Name,
        [string]$HistoryName = $null,
        [Type]$EntryClass = [EntryBase],
        [Action[string,string,string]]$SetStatus = $null
    )

    if (-not $SetStatus) {
        # デフォルト実装: 標準出力のみ
        $SetStatus = [Action[string,string,string]]{
            param($level,$component,$message)
            $prefix = "[$level][$component]"
            Write-Host "$prefix $message"
        }
    }

    # 履歴ファイル準備
    $baseDir = Join-Path $env:APPDATA "GUITools\data"
    if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }

    $HistoryFile = if ([string]::IsNullOrWhiteSpace($HistoryName)) {
        Join-Path $baseDir "history_$Name.json"
    } else {
        Join-Path $baseDir "history_$HistoryName.json"
    }

    $cbRef = $control
    $control.Tag = @{
        Component           = $Name
        HistoryFile         = $HistoryFile
        History             = @()
        EntryClass          = $EntryClass

        LoadHistory         = { Load-History $cbRef }.GetNewClosure()
        SaveHistory         = { Save-History $cbRef }.GetNewClosure()
        RefreshList         = { param($Keyword) Refresh-List -cb $cbRef -Keyword $Keyword }.GetNewClosure()
        AddHistory          = { param($Keyword, $Entry) Add-History -cb $cbRef -Keyword $Keyword -Entry $Entry }.GetNewClosure()
        GetHistory          = { param($Keyword) Get-History -cb $cbRef -Keyword $Keyword }.GetNewClosure()

        Entered             = [Action[string]] {
            param($kw)
            $SetStatus.Invoke("Info",$cbRef.Tag.Component,"入力完了: $kw")
        }.GetNewClosure()
        
        SkipNextKeyUpReturn = $false
        SetStatus           = $SetStatus
    }

    # Loadedイベント
    $control.Add_Loaded({
        param($sender,$e)
        $sender.ApplyTemplate()
        $editable = $sender.Template.FindName("PART_EditableTextBox",$sender)
        if (-not $editable) { return }

        $editable.Add_KeyDown({
            param($s,$e)
            $comboRef = $s.TemplatedParent
            if ($e.Key -eq "Return") {
                $comboRef.Tag.SkipNextKeyUpReturn = $true
                $e.Handled = $true
                $comboRef.IsDropDownOpen = $false
                $comboRef.Tag.Entered.Invoke([string]$comboRef.Text)
            }
        })

        $editable.Add_KeyUp({
            param($s,$e)
            $comboRef = $s.TemplatedParent
            if ($e.Key -eq "Return") {
                if ($comboRef.Tag.SkipNextKeyUpReturn) {
                    $comboRef.Tag.SkipNextKeyUpReturn = $false
                    return
                }
                $comboRef.Tag.RefreshList.Invoke([string]$comboRef.Text)
                $comboRef.SelectedIndex = -1
            }
        })

        $sender.Tag.LoadHistory.Invoke()
        $sender.Tag.RefreshList.Invoke("")
        $sender.Tag.SetStatus.Invoke("Info",$sender.Tag.Component,"履歴ロード完了")
    })

    # SelectionChangedイベント
    $control.Add_SelectionChanged({
        param($s,$e)
        if ($s.SelectedItem) { $s.Tag.Entered.Invoke([string]$s.SelectedItem) }
    })
}