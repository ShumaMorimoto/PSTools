setData([int]$row, [PSCustomObject]$item, [PSCustomObject]$data) {
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
