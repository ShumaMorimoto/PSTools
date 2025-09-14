class OTGSheetDAO:OTGoogleDAO {
    static $scope = "https://www.googleapis.com/auth/spreadsheets"
    static $accessToken = $null

    [object]$TBL = @{}
    [string]$spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU" #デフォルト
    [object]$sheets = $null

    OTGSheetDAO([string]$spreadsheetId) {
        $this.spreadsheetId = $spreadsheetId
        $this.initialize()
    }
    [void] initialize() {
        [OTGSheetDAO]::GetToken()
        $null = $this.GetSheets()
    }
    static [void] GetToken() {
        [OTGSheetDAO]::accessToken = [OTGoogleDAO]::GetToken([OTGSheetDAO]::scope)
    }
    [object] GetSheets() {
        $uri = "https://sheets.googleapis.com/v4/spreadsheets/$($this.spreadSheetID)"
        $ss = Invoke-RestMethod -Method GET -Uri $uri -Headers @{"Authorization" = "Bearer  $([OTGSheetDAO]::accessToken)" }
        $this.sheets = $ss.sheets
        return $this.sheets
    }
    [object]GetTable([string]$dataname, [string]$range) {
        if (-not $this.TBL.Contains($dataname)) {
            $parts = $range -split "!"
            $sheetName = $parts[0]
            $range = $parts[1]
            $sheetId = ($this.sheets.properties | Where-Object { $_.title -eq $sheetName }).sheetID           
            $this.TBL.Add($dataname, [GsTable]::new($this.spreadsheetId, $dataname, $sheetid, $sheetname, $range ))
        }
        return $this.TBL[$dataname]
    }
    static [hashtable]toIndex([string]$a1) {
        # 正規表現で列と行を分離（例："B4" → "B", "4"）
        if ($a1 -match '^([A-Z]+)(\d+)$') {
            $colLetters = $matches[1]
            $rowNumber = [int]$matches[2]
            # 列文字 → 数値変換（例："B" → 2, "AA" → 27）
            $colNumber = 0
            foreach ($char in $colLetters.ToCharArray()) {
                $colNumber = $colNumber * 26 + ([int][char]$char - [int][char]'A' + 1)
            }

            return [ordered]@{Row = $rowNumber; Column = $colNumber }
        }
        else {
            throw "Invalid A1 format: $a1"
        }
    }
    static [string]toA1([hashtable]$range) {
        if ($range.Row -lt 1 -or $range.Column -lt 1) {
            throw "Row and Column must be >= 1"
        }
        # 列番号 → アルファベット（例：2 → "B", 27 → "AA"）
        $colLetters = ""
        $col = $range.Column
        while ($col -gt 0) {
            $col--
            $char = [char]($col % 26 + [int][char]'A')
            $colLetters = "$char$colLetters"
            $col = [math]::Floor($col / 26)
        }
        return [string]($colLetters + [string]($range.Row))
    } 
}
