Show() {
        if (-not [OTExcelDAO]::excel.Visible) {
            [OTExcelDAO]::excel.Visible = $true
            if ($this.book.ReadOnly) { $this.book.ChangeFileAccess(2) }
        } 
    }
