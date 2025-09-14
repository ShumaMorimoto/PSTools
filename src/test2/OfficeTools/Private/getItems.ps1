getItems($row, $col, $count) {
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
