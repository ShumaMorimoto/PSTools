# ================================
# メイン関数
# ================================
function Init-SearchComboLogic {
    param(
        [System.Windows.Controls.ComboBox]$control,
        [string]$Name,
        [string]$HistoryName = $null,
        [Type]$EntryClass = [EntryBase],
        [Action[string,string,string]]$SetStatus = $null
    )

    if (-not $SetStatus) {
        $SetStatus = [Action[string,string,string]]{
            param($level,$component,$message)
            Write-Host "[$level][$component] $message"
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

    # Tag に責務を集約
    $control.Tag = @{
        Component       = $Name
        HistoryFile     = $HistoryFile
        History         = @()
        EntryClass      = $EntryClass

        LoadHistory     = { Load-History $cbRef }.GetNewClosure()
        SaveHistory     = { Save-History $cbRef }.GetNewClosure()
        RefreshList     = { param($Keyword) Refresh-List -cb $cbRef -Keyword $Keyword }.GetNewClosure()
        AddHistory      = { param($Keyword,$Entry) Add-History -cb $cbRef -Keyword $Keyword -Entry $Entry }.GetNewClosure()
        GetHistory      = { param($Keyword) Get-History -cb $cbRef -Keyword $Keyword }.GetNewClosure()

        Entered         = [Action[string]] {
            param($kw)
            $cbRef.Tag.SetStatus.Invoke("Info","入力完了: $kw")
        }.GetNewClosure()

        # SetStatus をラッパー化（呼び出しは2変数）
        SetStatus       = [Action[string,string]] {
            param($level,$message)
            $SetStatus.Invoke($level,$cbRef.Tag.Component,$message)
        }.GetNewClosure()

        # Enter直前のテキストを保持（コンボごとに独立）
        TextBeforeEnter = $null
    }

    # ComboBox本体にイベント登録
    $control.Add_KeyDown({
        param($sender,$e)

        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $sender.Tag.TextBeforeEnter = $sender.Text
            return
        }

        if ($e.Key -in $script:KeysToIgnore) { return }
        if ($e.PSObject.Properties.Name -contains 'ImeProcessed' -and $e.ImeProcessed) { return }

        Start-Sleep -Milliseconds 10
        $sender.Tag.RefreshList.Invoke([string]$sender.Text)
    }.GetNewClosure())

    $control.Add_KeyUp({
        param($sender,$e)

        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $currentText = $sender.Text
            if ($sender.Tag.TextBeforeEnter -ne $currentText) {
                # IME変換確定
                $sender.Tag.RefreshList.Invoke([string]$currentText)
            } else {
                # 入力完了Enter
                $sender.Tag.Entered.Invoke([string]$currentText)
            }
            $sender.Tag.TextBeforeEnter = $null
        }
    }.GetNewClosure())

    # 初期化
    $control.Add_Loaded({
        param($sender,$e)
        $sender.Tag.LoadHistory.Invoke()
        $sender.Tag.RefreshList.Invoke("")
        $sender.Tag.SetStatus.Invoke("Info","履歴ロード完了")
    }.GetNewClosure())

    # SelectionChanged → Entered
    $control.Add_SelectionChanged({
        param($s,$e)
        if ($s.SelectedItem) { $s.Tag.Entered.Invoke([string]$s.SelectedItem) }
    }.GetNewClosure())
}