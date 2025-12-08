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
