GetSheets() {
        $uri = "https://sheets.googleapis.com/v4/spreadsheets/$($this.spreadSheetID)"
        $ss = Invoke-RestMethod -Method GET -Uri $uri -Headers @{"Authorization" = "Bearer  $([OTGSheetDAO]::accessToken)" }
        $this.sheets = $ss.sheets
        return $this.sheets
    }
