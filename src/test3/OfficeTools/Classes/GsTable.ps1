class GsTable :AbstractTable {
    [string] $spreadsheetId
    [string] $sheetname
    [string] $sheetId
    [string] $range
    [object] $oHeader = [ordered]@{}
    [object] $oRows = @()
    [object] $topCel
        
    GsTable([string]$spreadsheetId, [string]$dataname, [int]$sheetId, [string]$sheetName, [string]$range) {
        $this.spreadsheetId = $spreadsheetId
        $this.sheetId = $sheetId
        $this.sheetName = $sheetName
        $this.range = $range

        $parts = $this.range -split ":"
        $this.topCel = [OTGSheetDAO]::toIndex($parts[0])        
        $this.Load()
    }
    [object]Load() {
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
    [hashtable[]] GetRows([int[]]$rows) {
        return $rows | ForEach-Object { $this.oRows[$_] }
    }
    [hashtable[]] GetRows() {
        return $this.oRows
    }
    [void]UpdateRow([int]$num, [hashtable]$data) {
        $row = $this.oRows[$num]

        # 更新データの置き換え
        foreach ($prop in $data.keys | Where-Object { $_ -ne '_row' }) {
            if ($row.keys.Contains($prop)) {
                $row.$($prop.Name) = $prop.Value
            }
        }
        $this.UpdateRow($row)
    }
    [void]UpdateRow([hashtable]$row) {
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
    [void]InsertRow([int]$idx) {
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
    [hashtable] ToHashTable([string]$key) {
        $result = [ordered]@{}
        foreach ($item in $this.oRows) {
            if ($item.Keys -contains $key) {
                $result[$item[$key]] = $item
            }
        }
        return $result
    }
    [hashtable]ToHashTable() {
        $key = $this.oHeader[0]
        return $this.ToHashTable($key)
    }
}
