function Invoke-FileAction {
    param($value, $SetStatus)
    try {
        Start-Process $value
        $SetStatus.Invoke("Info","開きました: $value")
    }
    catch {
        $SetStatus.Invoke("Error","開けません: $value")
    }
}

function Invoke-UrlAction {
    param($value, $SetStatus)
    Start-Process $value
    $SetStatus.Invoke("Info","URLを開きました: $value")
}

function Invoke-CopyAction {
    param($values, $SetStatus)
    $text = $values -join "`r`n"
    [System.Windows.Clipboard]::SetText($text)
    $SetStatus.Invoke("Info","コピー完了")
}

function Init-DetailListLogic {
    param(
        [System.Windows.Controls.ListBox]$control,
        [string]$Name,
        [string]$TemplateName = "default",
        [Action[string,string,string]]$SetStatus = $null
    )

    if (-not $SetStatus) {
        $SetStatus = [Action[string,string,string]]{
            param($level,$component,$message)
            $prefix = "[$level][$component]"
            Write-Host "$prefix $message"
        }
    }

    # --- ListBox 基本設定 ---
    $control.SelectionMode = "Extended"

    # --- テンプレート読み込み ---
    $file = Join-Path $script:ModuleRoot "data\template_$TemplateName.json"
    $tplRef = $null
    if (Test-Path $file) {
        try {
            $tplRef = Get-Content $file -Raw | ConvertFrom-Json -AsHashtable
        }
        catch {
            $tplRef = $null
        }
    }
    if (-not $tplRef) {
        $tplRef = @{ "ERROR" = "テンプレートがありません" }
    }

    $lbRef = $control
    $control.Tag = @{
        Component = $Name
        Template  = $tplRef

        # --- データ設定 ---
        SetData = {
            param($entry)

            $lbRef.Items.Clear()

            foreach ($tpl in $tplRef.GetEnumerator()) {
                $value = Invoke-Template -Template $tpl.Value -Data $entry
                $item = New-Object System.Windows.Controls.ListBoxItem
                $item.Content = "$($tpl.Key): $value"
                $item.Tag     = @{ 項目 = $tpl.Key; 値 = $value }
                $lbRef.Items.Add($item) | Out-Null
            }
            $lbRef.Tag.SetStatus.Invoke("Info","データ設定完了")
        }.GetNewClosure()

        # --- 複数コピー ---
        Entered = [Action[System.Collections.IList]] {
            param($selected)
            if ($selected.Count -gt 0) {
                $values = $selected | ForEach-Object { $_.Tag.値 }
                Invoke-CopyAction $values $lbRef.Tag.SetStatus
            }
        }.GetNewClosure()

        # --- 1件固有アクション ---
        Action = [Action[System.Windows.Controls.ListBoxItem]] {
            param($item)

            $value = $item.Tag.値

            if (Test-Path $value) {
                Invoke-FileAction $value $lbRef.Tag.SetStatus
            }
            elseif ($value -match '^https?://') {
                Invoke-UrlAction $value $lbRef.Tag.SetStatus
            }
            else {
                Invoke-CopyAction @($value) $lbRef.Tag.SetStatus
            }
        }.GetNewClosure()

        SetStatus = [Action[string,string]] {
            param($level,$message)
            $SetStatus.Invoke($level,$lbRef.Tag.Component,$message)
        }.GetNewClosure()
    }

    # --- イベント登録 ---
    $control.Add_PreviewKeyDown({
        param($sender, $e)

        if ($sender.SelectedItems.Count -eq 0) { return }

        # Enter → 複数コピー
        if ($e.Key -eq "Return" -and -not $e.KeyboardDevice.Modifiers.HasFlag("Control")) {
            $e.Handled = $true
            $sender.Tag.Entered.Invoke($sender.SelectedItems)
            return
        }

        # Ctrl+Enter → 1件アクション
        if ($e.Key -eq "Return" -and $e.KeyboardDevice.Modifiers.HasFlag("Control")) {
            $e.Handled = $true
            $sender.Tag.Action.Invoke($sender.SelectedItems[0])
            return
        }
    })

    # ダブルクリック → 1件アクション
    $control.Add_MouseDoubleClick({
        param($sender, $e)
        if ($sender.SelectedItems.Count -gt 0) {
            $sender.Tag.Action.Invoke($sender.SelectedItems[0])
        }
    })
}
