lastRow() {
        $cell = $this.sheet.Cells($this.startRow(), $this.range.Column)
        $lastrow = switch ($cell.Text) {
            "" { $this.startRow() - 1 }
            default { $cell.End( - 4121).row }
        }
        return $lastrow
    }
