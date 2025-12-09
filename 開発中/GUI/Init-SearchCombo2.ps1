function Init-SearchComboLogic {
    param(
        [System.Windows.Controls.ComboBox]$control,
        [string]$Name,
        [string]$HistoryName = $null,
        [Type]$EntryClass = [EntryBase],
        [Action[string, string, string]]$SetStatus = $null
    )

    if (-not $SetStatus) {
        $SetStatus = [Action[string, string, string]] {
            param($level, $component, $message)
            Write-Host "[$level][$component] $message"
        }
    }

    # 履歴ファイル準備
    $baseDir = Join-Path $env:APPDATA "GUITools\data"
    if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
    $HistoryFile = if ([string]::IsNullOrWhiteSpace($HistoryName)) {
        Join-Path $baseDir "history_$Name.json"
    }
    else {
        Join-Path $baseDir "history_$HistoryName.json"
    }

    $cbRef = $control

    # Tag に責務を集約
    $control.Tag = @{
        Component       = $Name
        HistoryFile     = $HistoryFile
        History         = @()
        EntryClass      = $EntryClass

        LoadHistory     = { Load-History $cbRef }.GetNewClosure()
        SaveHistory     = { Save-History $cbRef }.GetNewClosure()
        RefreshList     = {
            param($Keyword)
            Write-Host "→ Refresh実行: Text=[$Keyword]"
            Refresh-List -cb $cbRef -Keyword $Keyword
        }.GetNewClosure()
        AddHistory      = { param($Keyword, $Entry) Add-History -cb $cbRef -Keyword $Keyword -Entry $Entry }.GetNewClosure()
        GetHistory      = { param($Keyword) Get-History -cb $cbRef -Keyword $Keyword }.GetNewClosure()

        Entered         = [Action[string]] {
            param($kw)
            $cbRef.Tag.SetStatus.Invoke("Info", "入力完了: $kw")
        }.GetNewClosure()

        # SetStatus をラッパー化（呼び出しは2変数）
        SetStatus       = [Action[string, string]] {
            param($level, $message)
            $SetStatus.Invoke($level, $cbRef.Tag.Component, $message)
        }.GetNewClosure()
    }

    # ----------------------------------------------------
    # TextInputEvent: 通常入力 or IME確定 → Refresh
    # ----------------------------------------------------
    $control.AddHandler(
        [System.Windows.Input.TextCompositionManager]::TextInputEvent,
        [System.Windows.Input.TextCompositionEventHandler]{ param($s,$e)
            Write-Host "TextInputEvent: e.Text=[$($e.Text)] Combo.Text=[$($s.Text)]"
            $s.Tag.RefreshList.Invoke([string]$s.Text)
        },
        $true
    )

    # ----------------------------------------------------
    # KeyDown(Return): Enterキー押下 → Entered
    # ----------------------------------------------------
    $control.Add_KeyDown({
        param($sender,$e)
        if ($e.Key -eq [System.Windows.Input.Key]::Return) {
            Write-Host "KeyDown(Return): Combo.Text=[$($sender.Text)]"
            $sender.Tag.Entered.Invoke([string]$sender.Text)
        }
    }.GetNewClosure())

    # 初期化
    $control.Add_Loaded({
        param($sender, $e)
        $sender.Tag.LoadHistory.Invoke()
        $sender.Tag.RefreshList.Invoke("")
        $sender.Tag.SetStatus.Invoke("Info", "履歴ロード完了")
    }.GetNewClosure())

    # SelectionChanged → Entered
    $control.Add_SelectionChanged({
        param($s, $e)
        if ($s.SelectedItem) { $s.Tag.Entered.Invoke([string]$s.SelectedItem) }
    }.GetNewClosure())
}