function Refresh-List {
    param([System.Windows.Controls.ComboBox]$cb, [string]$Keyword = "")
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($h in $cb.Tag.History) {
        $kw = $h.Keyword
        if ($kw) {
            if ([string]::IsNullOrWhiteSpace($Keyword) -or $kw -like "$Keyword*" -or $kw -like "*$Keyword*") {
                $items.Add($kw)
            }
        }
    }
    $cb.ItemsSource = $items
}
