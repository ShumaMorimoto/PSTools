UpdateRow([hashtable]$row) {
        #更新範囲取得
        $this.range -match "^([A-Z]+)\d+:([A-Z]+)\d+$"
        $rowRange = "$($matches[1])$($row._row):$($matches[2])$($row._row)"

        $method = 'PUT'
        $contenttype = 'application/json'
        $valueInputOption = 'USER_ENTERED'
        $uri = "https://sheets.googleapis.com/v4/spreadsheets/$($this.spreadSheetID)/values/$($this.sheetname)!$rowRange" + "?valueInputOption=$valueInputOption"

        $data = , (@($this.oHeader | ForEach-Object { $row.$_ }))
        $json = @{ values = $data } | ConvertTo-Json -Depth 3

        #$data = [string[]]$this.oHeader | ForEach-Object { $row.$_ }
        #        $values = New-Object 'System.Collections.ArrayList'
        #        $values.Add($data) | Out-Null
        #        $json = @{values = @($values) } | ConvertTo-Json

        Invoke-RestMethod -Method $method -Uri $uri -Body $json -ContentType $contenttype -Headers @{"Authorization" = "Bearer $([OTGSheetDAO]::accessToken)" }
    }
