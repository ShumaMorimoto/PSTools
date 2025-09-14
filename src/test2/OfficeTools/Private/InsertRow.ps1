InsertRow([int]$idx) {
        $suffix = "$($this.spreadSheetID)" + ":batchUpdate"
        $uri = "https://sheets.googleapis.com/v4/spreadsheets/$suffix"

        $row = $this.oRows[$idx]._row

        $json = @{requests = @(
                @{
                    "insertDimension" = @{
                        range             = @{sheetId = $this.sheetId; dimension = "ROWS"; startIndex = $row; endIndex = $row + 1 }
                        inheritFromBefore = $false
                    }
                }
            )
        } | ConvertTo-Json -depth 5

        Invoke-RestMethod -Method Post -Uri $uri `
            -Body $json `
            -ContentType "application/json" `
            -Headers @{"Authorization" = "Bearer $([OTGSheetDAO]::accessToken)" }
    }
