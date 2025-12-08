function Init-DetailGridLogic {
    param(
        [System.Windows.Controls.DataGrid]$grid,
        [string]$Name,
        [string]$TemplateName = "default"
    )

    $grid.AutoGenerateColumns = $false
    $grid.IsReadOnly = $true
    $grid.HeadersVisibility = "Column"
    $grid.RowHeaderWidth = 0
    $grid.SelectionMode = "Extended"
    $grid.SelectionUnit = "FullRow"

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
    $gridRef = $grid
    $grid.Tag = @{
        Template = $tplRef

        SetData = {
            param($entry)
            $items = @()
            foreach ($tpl in $tplRef.GetEnumerator()) {
                $value = [string]$tpl.Value
                foreach ($prop in $entry.PSObject.Properties.Name) {
                    $value = $value -replace "<$prop>", [string]$entry.$prop
                }
                $items += New-Object PSObject -Property @{ 項目 = $tpl.Key; 値 = $value }
            }
            $gridRef.ItemsSource = $items
        }.GetNewClosure()

        Entered = [Action[System.Collections.IList]] {
            param($selected)
            if ($selected.Count -gt 0) {
                $text = ($selected | ForEach-Object { $_.値 }) -join "`r`n"
                [System.Windows.Clipboard]::SetText($text)
            }
        }
    }

    # --- イベント登録 ---
    $grid.Add_PreviewKeyDown({
        param($sender, $e)
        if ($e.Key -eq "Return" -and $sender.SelectedItems.Count -gt 0) {
            $e.Handled = $true
            $sender.Tag.Entered.Invoke($sender.SelectedItems)
        }
    })

    $grid.Add_MouseDoubleClick({
        param($sender, $e)
        if ($sender.SelectedItems.Count -gt 0) {
            $sender.Tag.Entered.Invoke($sender.SelectedItems)
        }
    })
}