function Add-HistoryEntry {
    param(
        [System.Windows.Controls.ComboBox]$cb,
        [psobject]$Entry
    )

    $hf = $cb.Tag.HistoryFile
    $hist = $cb.Tag.History

    $item = $hist | Where-Object { $_.keyword -eq $Entry.keyword }
    if ($item) {
        foreach ($point in $Entry.selected) {
            $exists = $item.selected | Where-Object { $_.lat -eq $point.lat -and $_.lon -eq $point.lon }
            if (-not $exists) { $item.selected += $point }
        }
        $item.lastUsed = (Get-Date).ToString("s")
    }
    else {
        $Entry | Add-Member -NotePropertyName lastUsed -NotePropertyValue (Get-Date).ToString("s")
        $hist += $Entry
    }

    $hist = $hist | Sort-Object { [datetime]$_.lastUsed } -Descending
    $hist | ConvertTo-Json -Depth 5 | Out-File $hf -Encoding UTF8

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($h in $hist) { if ($h.keyword) { $items.Add([string]$h.keyword) } }
    $cb.ItemsSource = $items

    $cb.Tag.History = $hist
}

function New-AutoCompleteComboBox {
    param([string]$Name)

    $comboBox = New-Object System.Windows.Controls.ComboBox
    $comboBox.IsEditable = $true
    $comboBox.Margin = "10"
    $comboBox.FontSize = 16

    $HistoryFile = "history_$Name.json"
    $history = @()
    if (Test-Path $HistoryFile) {
        try { $history = Get-Content $HistoryFile -Raw | ConvertFrom-Json } catch { $history = @() }
    }
    $initialItems = New-Object System.Collections.Generic.List[string]
    foreach ($h in $history) { if ($h.keyword) { $initialItems.Add([string]$h.keyword) } }
    $comboBox.ItemsSource = $initialItems

    $comboBox.Tag = [ordered]@{
        HistoryFile = $HistoryFile
        History     = $history
    }

    # クロージャで AddHistory を登録
    $cbRef = $comboBox
    $addHistory = {
        param($Entry)
        Add-HistoryEntry -cb $cbRef -Entry $Entry
    }.GetNewClosure()
    $comboBox.Tag.AddHistory = $addHistory
    
    return $comboBox
}

Add-Type -AssemblyName PresentationFramework

# 外出し関数と New-AutoCompleteComboBox を定義済みと仮定

# コンボ生成
$combo = New-AutoCompleteComboBox -Name "search"

# テスト用エントリ
$entry = @{
    keyword  = "Tokyo"
    selected = @(@{ lat = 35.68; lon = 139.76 })
}

# Tag経由で履歴追加（UIイベント不要）
$combo.Tag.AddHistory.Invoke($entry)

# 確認：ItemsSource に "Tokyo" が入っているか
$combo.ItemsSource