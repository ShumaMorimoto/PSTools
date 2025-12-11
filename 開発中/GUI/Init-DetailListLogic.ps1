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
    $file = Join-Path $script:ModuleRoot "\data\template_$TemplateName.json"
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
        # デフォルトテンプレート
        $tplRef = @{
            "ERROR" = "テンプレートがありません"
        }
    }

    $lbRef = $control
    $control.Tag = @{
        Component = $Name
        Template  = $tplRef

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

        Entered = [Action[System.Collections.IList]] {
            param($selected)
            if ($selected.Count -gt 0) {
                $text = ($selected | ForEach-Object { $_.Tag.値 }) -join "`r`n"
                [System.Windows.Clipboard]::SetText($text)
                $lbRef.Tag.SetStatus.Invoke("Info","コピー完了（値のみ）")
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
        if ($e.Key -eq "Return" -and $sender.SelectedItems.Count -gt 0) {
            $e.Handled = $true
            $sender.Tag.Entered.Invoke($sender.SelectedItems)
        }
    })

    $control.Add_MouseDoubleClick({
        param($sender, $e)
        if ($sender.SelectedItems.Count -gt 0) {
            $sender.Tag.Entered.Invoke($sender.SelectedItems)
        }
    })
}