GsTable([string]$spreadsheetId, [string]$dataname, [int]$sheetId, [string]$sheetName, [string]$range) {
        $this.spreadsheetId = $spreadsheetId
        $this.sheetId = $sheetId
        $this.sheetName = $sheetName
        $this.range = $range

        $parts = $this.range -split ":"
        $this.topCel = [OTGSheetDAO]::toIndex($parts[0])        
        $this.Load()
    }
