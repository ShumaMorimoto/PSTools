function Init-DetailListLogic {
    param(
        [System.Windows.Controls.ListBox]$control,
        [string]$Name,
        [string]$TemplateName = "default",
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

    # --- ListBox 基本設定 ---
    $control.SelectionMode = "Extended"

    # --- テンプレート読み込み ---
    $baseDir = Join-Path $env:APPDATA "GUITools\data"
    if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
    $file = Join-Path $baseDir "template_$TemplateName.json"

    $tplRef = $null
    if (Test-Path $file) {
        try { $tplRef = Get-Content $file -Raw | ConvertFrom-Json -AsHashtable } catch { $tplRef = $null }
    }
    if (-not $tplRef) {
        $tplRef = @{
            "位置" = "<緯度>,<経度>"
            "名称" = "<拠点名>"
            "住所" = "<住所>"
        }
    }

    # --- Tagにロジック注入 ---
    $lbRef = $control
    $control.Tag = @{
        Component  = $Name
        Template   = $tplRef

        SetData = {
            param($entry)
            $lbRef.Items.Clear()
            foreach ($tpl in $tplRef.GetEnumerator()) {
                $value = [string]$tpl.Value
                foreach ($prop in $entry.PSObject.Properties.Name) {
                    $value = $value -replace "<$prop>", [string]$entry.$prop
                }
                $item = New-Object System.Windows.Controls.ListBoxItem
                $item.Content = "$($tpl.Key): $value"   # 表示用（項目: 値）
                $item.Tag     = @{ 項目 = $tpl.Key; 値 = $value } # 内部データ（項目＋値）
                $lbRef.Items.Add($item) | Out-Null
            }
            $lbRef.Tag.SetStatus.Invoke("Info","データ設定完了")
        }.GetNewClosure()

        Entered = [Action[System.Collections.IList]] {
            param($selected)
            if ($selected.Count -gt 0) {
                # 値だけコピー（Tagから値を参照）
                $text = ($selected | ForEach-Object { $_.Tag.値 }) -join "`r`n"
                [System.Windows.Clipboard]::SetText($text)
                $lbRef.Tag.SetStatus.Invoke("Info","コピー完了（値のみ）")
            }
        }.GetNewClosure()

        # SetStatus をラッパー化（呼び出しは2変数）
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