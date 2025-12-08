Add-Type -AssemblyName PresentationFramework

function Convert-EntryToItems {
    param(
        [System.Windows.Controls.DataGrid]$GridRef,
        [object]$Entry,
        [hashtable]$Template
    )

    if ($null -eq $Entry) { $GridRef.ItemsSource = @(); return }

    $items = @()
    foreach ($tpl in $Template.GetEnumerator()) {
        $value = [string]$tpl.Value
        foreach ($prop in $Entry.PSObject.Properties.Name) {
            $value = $value -replace "<$prop>", [string]$Entry.$prop
        }
        # 余計なプロパティ混入防止：プロパティを固定化
        $items += (New-Object PSObject -Property @{
            項目 = $tpl.Key
            値   = $value
        })
    }

    $GridRef.ItemsSource = $items
}

function New-DetailGrid {
    param(
        [string]$Name,
        [string]$TemplateName = "default"
    )

    $grid = New-Object System.Windows.Controls.DataGrid
    $grid.Name = $Name
    $grid.AutoGenerateColumns = $false
    $grid.IsReadOnly = $true
    $grid.HeadersVisibility = "Column"  # 行ヘッダー非表示
    $grid.RowHeaderWidth = 0            # 念押しで幅ゼロ
    $grid.CanUserAddRows = $false       # 追加行プレースホルダー無効
    $grid.SelectionMode = "Extended"
    $grid.SelectionUnit = "FullRow"
    $grid.Margin = "10"
    $grid.GridLinesVisibility = "None"

    # 列定義（明示固定）
    $grid.Columns.Clear()
    $col1 = New-Object System.Windows.Controls.DataGridTextColumn
    $col1.Header = "項目"
    $col1.Binding = New-Object System.Windows.Data.Binding "項目"
    $grid.Columns.Add($col1)

    $col2 = New-Object System.Windows.Controls.DataGridTextColumn
    $col2.Header = "値"
    $col2.Binding = New-Object System.Windows.Data.Binding "値"
    $grid.Columns.Add($col2)

    $gridRef = $grid

    # --- テンプレート読み込み（内部統合） ---
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
    # -----------------------------------------

    $grid.Tag = @{
        Template = $tplRef

        SetData = {
            param($entry)
            # 列再生成の可能性に備え、毎回自動列生成を明示無効＆Columns固定
            $gridRef.AutoGenerateColumns = $false
            if ($gridRef.Columns.Count -ne 2) {
                $gridRef.Columns.Clear()
                $c1 = New-Object System.Windows.Controls.DataGridTextColumn
                $c1.Header = "項目"
                $c1.Binding = New-Object System.Windows.Data.Binding "項目"
                $gridRef.Columns.Add($c1)

                $c2 = New-Object System.Windows.Controls.DataGridTextColumn
                $c2.Header = "値"
                $c2.Binding = New-Object System.Windows.Data.Binding "値"
                $gridRef.Columns.Add($c2)
            }
            Convert-EntryToItems -GridRef $gridRef -Entry $entry -Template $tplRef
        }.GetNewClosure()

        # カスタマイズポイント：選択行コレクションを渡す
        Entered = [Action[System.Collections.IList]] {
            param($selected)
            if ($selected.Count -gt 0) {
                $text = ($selected | ForEach-Object { $_.値 }) -join "`r`n"
                [System.Windows.Clipboard]::SetText($text)
            }
        }
    }

    # Return確定（プレビューで既定動作抑止）
    $grid.Add_PreviewKeyDown({
        param($sender, $e)
        if ($e.Key -eq "Return" -and $sender.SelectedItems.Count -gt 0) {
            $e.Handled = $true
            $sender.Tag.Entered.Invoke($sender.SelectedItems)
        }
    })

    # ダブルクリック確定
    $grid.Add_MouseDoubleClick({
        param($sender, $e)
        if ($sender.SelectedItems.Count -gt 0) {
            $sender.Tag.Entered.Invoke($sender.SelectedItems)
        }
    })

    return $grid
}


# ダミーEntry
$dummyEntry = [PSCustomObject]@{
    拠点名 = "テスト拠点"
    住所   = "神奈川県横須賀市"
    緯度   = 35.28
    経度   = 139.67
}

# DetailGrid生成（テンプレート名指定）
$detailGrid = New-DetailGrid -Name "DetailGridTest" -TemplateName "default"

# Entryをセット
& $detailGrid.Tag.SetData $dummyEntry

# Enteredを差し替え（テスト用：ログ出力）
$detailGrid.Tag.Entered = {
    param([System.Collections.IList]$selected)
    $text = ($selected | ForEach-Object { "$($_.項目): $($_.値)" }) -join "`r`n"
    Write-Host "Entered invoked with:`n$text"
}

# Window作成
$window = New-Object System.Windows.Window
$window.Title = "DetailGrid テスト"
$window.Width = 420
$window.Height = 320

$panel = New-Object System.Windows.Controls.StackPanel
$panel.Margin = "10"
$window.Content = $panel

$panel.Children.Add($detailGrid)

# テスト用ボタン（選択確定を明示的に呼ぶ）
$testButton = New-Object System.Windows.Controls.Button
$testButton.Content = "選択確定テスト"
$testButton.Margin = "0,8,0,0"
$testButton.Add_Click({
    $detailGrid.Tag.Entered.Invoke($detailGrid.SelectedItems)
})
$panel.Children.Add($testButton)

# 表示
$window.ShowDialog() | Out-Null