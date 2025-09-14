getData([int]$row, [PSCustomObject]$item) {
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
