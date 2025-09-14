class ExTable :AbstractTable {
    [object] $sheet
    [object] $range
    [PSCustomObject] $oHeader = [ordered]@{}
    [PSCustomObject] $oRows = @()
        
    ExTable([object]$range) {
        $this.sheet = $range.WorkSheet
        $this.range = $range
        $this.oHeader = $this.GetHeader()
    }
    [object] GetHeader() {
        return $this.getItems($this.range.Row, $this.range.Column, $this.range.Columns.Count)
    }   
    [PSCustomObject] getItems($row, $col, $count) {
        $obj = [ordered]@{}
        while ($count -gt 0) {
            $cell = $this.sheet.Cells($row, $col)
            $text = $cell.Text
            if ($text -ne "") {
                $cols = $cell.MergeArea.Columns.Count
                if ($cols -eq 1) {
                    # $obj.Add($cell.Text, $col)
                    $obj[$cell.Text] = $col
                }
                else {
                    $obj2 = $this.getItems($row + 1, $col, $cols)
                    #$obj.Add($cell.Text, $obj2)
                    $obj[$cell.Text] = $obj2
                }
            }
            $count --; $col ++
        }
        return $obj
    }
    [PSCustomObject] GetRows([int[]]$rows) {
        $this.oRows = @()
        foreach ($row in $rows) {
            $this.oRows += ($this.getData($row, $this.oHeader) + @{"_row" = $row })
        }
        return $this.oRows
    }
    [PSCustomObject] GetRows() {
        [int]$start = $this.startRow()
        [int]$end = $this.lastRow()
        if ($start -gt $end) {
            return $null
        }
        return $this.GetRows(($start..$end))
    }
    [PSCustomObject]getData([int]$row, [PSCustomObject]$item) {
        $obj = [ordered]@{}
        foreach ($key in $item.Keys) {
            if ($item.$key -is [int]) {
                $cell = $this.sheet.Cells($row, $item.$key)
                if ($cell.Hyperlinks.Count -eq 0) {
                    $obj.Add($key, $cell.Text)
                }
                else {
                    $obj.Add($key, @{Text = $cell.Text; Address = $cell.HyperLinks[1].Address })
                }
            }
            else {
                $obj.Add($key, $this.getData($row, $item.$key))
            }
        }
        return $obj
    }
    [PSCustomObject] AddRows([PSCustomObject[]]$data) {
        $lastrow = $this.lastRow() + 1
        foreach ($record in $data) {
            $this.setData($lastrow, $this.oHeader, $record)
        }
        $this.oROws = $this.GetRows()
        return $this.oRows
    }
    [void]setData([int]$row, [PSCustomObject]$item, [PSCustomObject]$data) {
        if ($null -ne $data) {
            foreach ($key in $item.Keys) {
                if ($item.$key -is [int]) {
                    $this.sheet.Cells($row, $item.$key) = $data.$key
                }
                else {
                    $this.setData($row, $item.$key, $data.$key)
                }
            }
        }
    }
    [PSCustomObject] SearchRows([ScriptBlock] $compfunc) {
        return ($this.oRows | Where-Object { &$compfunc $_ } )
    }
    [PSCustomObject] toObject() {
        return [PSCustomObject]@{header = $this.oHeader; data = $this.oRows }
    }
    [int] startRow() {
        return $this.range.Row + $this.range.Rows.Count
    }  
    [int] lastRow() {
        $cell = $this.sheet.Cells($this.startRow(), $this.range.Column)
        $lastrow = switch ($cell.Text) {
            "" { $this.startRow() - 1 }
            default { $cell.End( - 4121).row }
        }
        return $lastrow
    }  
    [boolean] Sort([ScriptBlock] $orderfunc) {
        $keycol = $this.sheet.Columns.Count
        
        foreach ($data in $this.oRows) { $this.sheet.Cells($data._row, $keycol) = &$orderfunc $data }

        $cell1 = $this.sheet.Cells(($this.oRows._row | Select-Object -First 1), $this.range.Column)
        $cell2 = $this.sheet.Cells(($this.oRows._row | Select-Object -Last 1), $keycol)
        $drange = $this.sheet.Range($cell1, $cell2)
        $key = $drange.Columns[$keycol]
        # $key.ClearContents()
        return $drange.Sort($key, 1)
    } 
}
