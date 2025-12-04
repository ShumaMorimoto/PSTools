function Load-History {
    param([System.Windows.Controls.ComboBox]$cb)

    $file = $cb.Tag.HistoryFile
    if (Test-Path $file) {
        try {
            $json = Get-Content $file -Raw | ConvertFrom-Json
            $entries = @()
            foreach ($o in $json) {
                $cls = $cb.Tag.EntryClass
                $entries += $cls::FromJson($o)
            }
            return $entries
        }
        catch { return @() }
    }
    return @()
}

function Save-History {
    param([System.Windows.Controls.ComboBox]$cb)

    $file = $cb.Tag.HistoryFile
    $hist = $cb.Tag.History
    $hist | ForEach-Object { $_.ToJson() } | Out-File $file -Encoding UTF8
}

function Refresh-List {
    param([System.Windows.Controls.ComboBox]$cb, [string]$Keyword = "")

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($h in $cb.Tag.History) {
        $kw = $h.GetKeyword()
        if ($kw) {
            if ([string]::IsNullOrWhiteSpace($Keyword)) {
                $items.Add($kw)
            }
            elseif ($kw -like "$Keyword*" -or $kw -like "*$Keyword*") {
                $items.Add($kw)
            }
        }
    }
    $cb.ItemsSource = $items
}

function Add-History {
    param([System.Windows.Controls.ComboBox]$cb, [IHistoryEntry]$Entry)

    $hist = @($cb.Tag.History)
    $item = $hist | Where-Object { $_.GetKeyword() -eq $Entry.GetKeyword() }

    if ($item) {
        $point = $Entry.Selected
        $exists = $false
        foreach ($s in $item.Selected) {
            if ($cb.Tag.Compare.Invoke($s, $point)) { $exists = $true; break }
        }
        if (-not $exists) { $item.Selected.Add($point) }
        $item.lastUsed = (Get-Date).ToString("s")
    }
    else {
        $Entry.Selected = [System.Collections.Generic.List[object]]($Entry.Selected)
        $Entry | Add-Member -NotePropertyName lastUsed -NotePropertyValue (Get-Date).ToString("s")
        $hist += $Entry
    }

    $cb.Tag.History = $hist | Sort-Object { [datetime]$_.lastUsed } -Descending
    Save-History $cb
    Refresh-List -cb $cb
}

