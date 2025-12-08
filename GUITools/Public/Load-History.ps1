function Load-History {
    param([System.Windows.Controls.ComboBox]$cb)

    $file = $cb.Tag.HistoryFile
    $entries = @()
    if (Test-Path $file) {
        try {
            $json = Get-Content $file -Raw | ConvertFrom-Json
            foreach ($o in $json) {
                $cls = $cb.Tag.EntryClass
                $selected = [System.Collections.Generic.List[object]]::new()
                foreach ($s in $o.Selected) {
                    $selected.Add($cls::new($s))
                }
                $entries += @{
                    Keyword  = $o.Keyword
                    Selected = $selected
                    lastUsed = $o.lastUsed
                }
            }
        }
        catch { $entries = @() }
    }
    # return せずに直接設定
    $cb.Tag.History = $entries
}
