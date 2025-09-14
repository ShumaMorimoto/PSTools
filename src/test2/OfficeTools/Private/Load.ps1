Load() {
        $uri = "https://sheets.googleapis.com/v4/spreadsheets/$($this.spreadSheetID)/values/$($this.sheetname)!$($this.range)"
        #    $uri += "?valueRenderOption=$valueRenderOption"
        $result = Invoke-RestMethod -Method GET -Uri $uri -Headers @{"Authorization" = "Bearer $([OTGSheetDAO]::accessToken)" }

        $sheet = $result.values
        $Rows = $sheet.Count
        $Columns = $sheet[0].Count
        $Header = [string[]]$result.values[0]
        $Data = @()

        foreach ($Row in (1..($Rows - 1))) {
            $h = [Ordered]@{}
            foreach ($Column in 0..($Columns - 1)) {
                if ($sheet[0][$Column].Length -gt 0) {
                    $Name = $Header[$Column]
                    if ($sheet[$row].count -gt ($column)) {
                        $h.$Name = $Sheet[$Row][$Column]
                    }
                    else {
                        $h.$Name = ""
                    }
                }
            }
            $h._row = $this.topCel.Row + $Row 
            $Data += ($h)
        }
        $this.oHeader = $Header
        $this.oRows = $Data
        return $this.oRows
    }
