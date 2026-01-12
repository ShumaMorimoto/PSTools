function Save-History {
    param([System.Windows.Controls.ComboBox]$cb)

    $file = $cb.Tag.HistoryFile
    $hist = $cb.Tag.History

    $jsonList = @()
    foreach ($h in $hist) {
        $selectedJson = @()
        foreach ($s in $h.Selected) {
            # Entryオブジェクトをハッシュ化して保存
            $selectedJson += $s.ToJson()
        }
        $jsonList += @{
            Keyword  = $h.Keyword
            Selected = $selectedJson
            lastUsed = $h.lastUsed
        }
    }

    $jsonList | ConvertTo-Json -Depth 10 -Compress | Out-File $file -Encoding UTF8
}
