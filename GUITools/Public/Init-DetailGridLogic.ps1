function Init-DetailGridLogic {
    param(
        [System.Windows.Controls.DataGrid]$control,
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

    # --- DataGrid 基本設定 ---
    $control.AutoGenerateColumns = $false
    $control.IsReadOnly          = $true
    $control.HeadersVisibility   = "Column"
    $control.RowHeaderWidth      = 0
    $control.SelectionMode       = "Extended"
    $control.SelectionUnit       = "FullRow"

    # --- 列定義追加（項目／値） ---
    $control.Columns.Clear()

    $col1 = New-Object System.Windows.Controls.DataGridTextColumn
    $col1.Header = "項目"
    $col1.Binding = New-Object System.Windows.Data.Binding "項目"
    $control.Columns.Add($col1)

    $col2 = New-Object System.Windows.Controls.DataGridTextColumn
    $col2.Header = "値"
    $col2.Binding = New-Object System.Windows.Data.Binding "値"
    $control.Columns.Add($col2)

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
    $dgRef = $control
    $control.Tag = @{
        Component  = $Name
        Template   = $tplRef

        SetData = {
            param($entry)
            $items = @()
            foreach ($tpl in $tplRef.GetEnumerator()) {
                $value = [string]$tpl.Value
                foreach ($prop in $entry.PSObject.Properties.Name) {
                    $value = $value -replace "<$prop>", [string]$entry.$prop
                }
                $items += [PSCustomObject]@{ 項目 = $tpl.Key; 値 = $value }
            }
            $dgRef.ItemsSource = $items
            $SetStatus.Invoke("Info",$dgRef.Tag.Component,"データ設定完了")
        }.GetNewClosure()

        Entered = [Action[System.Collections.IList]] {
            param($selected)
            if ($selected.Count -gt 0) {
                $text = ($selected | ForEach-Object { $_.値 }) -join "`r`n"
                [System.Windows.Clipboard]::SetText($text)
                $SetStatus.Invoke("Info",$dgRef.Tag.Component,"コピー完了")
            }
        }.GetNewClosure()

        SetStatus = $SetStatus
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