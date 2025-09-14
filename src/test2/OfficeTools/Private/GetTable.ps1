GetTable([string]$dataname, [string]$range) {
        if (-not $this.TBL.Contains($dataname)) {
            $parts = $range -split "!"
            $sheetName = $parts[0]
            $range = $parts[1]
            $sheetId = ($this.sheets.properties | Where-Object { $_.title -eq $sheetName }).sheetID           
            $this.TBL.Add($dataname, [GsTable]::new($this.spreadsheetId, $dataname, $sheetid, $sheetname, $range ))
        }
        return $this.TBL[$dataname]
    }
