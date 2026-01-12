function Add-History {
    param([System.Windows.Controls.ComboBox]$cb, [string]$Keyword, [object]$Entry)
    $hist = @($cb.Tag.History)
    $item = $hist | Where-Object { $_.Keyword -eq $Keyword }
    if ($item) {
        $exists = $false
        foreach ($s in $item.Selected) { if ($s.Equals($Entry)) { $exists = $true; break } }
        if (-not $exists) { $item.Selected.Add($Entry) }
        $item.lastUsed = (Get-Date).ToString("s")
    }
    else {
        $newItem = @{ Keyword = $Keyword; Selected = [System.Collections.Generic.List[object]]::new(); lastUsed = (Get-Date).ToString("s") }
        $newItem.Selected.Add($Entry)
        $hist += $newItem
    }
    $cb.Tag.History = $hist | Sort-Object { [datetime]$_.lastUsed } -Descending
    Save-History $cb
    Refresh-List -cb $cb
}
