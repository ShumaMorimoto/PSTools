AddRows([PSCustomObject[]]$data) {
        $lastrow = $this.lastRow() + 1
        foreach ($record in $data) {
            $this.setData($lastrow, $this.oHeader, $record)
        }
        $this.oROws = $this.GetRows()
        return $this.oRows
    }
