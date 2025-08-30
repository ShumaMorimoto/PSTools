using module OfficeTools
Import-Module UMN-Google

# 必要な.NETライブラリをロード
#Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Google.Apis.Core.1.70.0\lib\netstandard2.0\Google.Apis.Core.dll
#Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Google.Apis.Auth.1.70.0\lib\netstandard2.0\Google.Apis.Auth.dll"
#Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Google.Apis.1.70.0\lib\netstandard2.0\Google.Apis.dll"
#Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Google.Apis.Sheets.v4.1.70.0.3819\lib\netstandard2.0\Google.Apis.Sheets.v4.dll"

class ToshinSheetDAO {
    static $credentialPath = "D:\tool\packages\smart-surf-425115-s5-9f82d14de193.json"
    static $scopes = @("https://www.googleapis.com/auth/spreadsheets")
    static $spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU"
    static $service = $null
    static $meigaraRG = "シート1!A2:G16"
    static $totalRG = "シート1!I18:L18"
    [datetime] $today
    [object] $meigara = $null
    [object] $total = $null

    static $meigaraHT = [ordered]@{
        銘柄   = ""
        略称   = ""
        コード  = ""
        更新日時 = "datetime"
        日付   = "datetime"
        価格   = "int"
        前日比  = "int"
    }
    static $totalHT = [ordered]@{
        日付  = "datetime"
        時価  = "string"
        損益  = "string"
        前日比 = "string"
    }


   ToshinSheetDAO() {
        $scopesList = New-Object 'System.Collections.Generic.List[string]'
        $scopesList.AddRange([string[]][ToshinSheetDAO]::scopes)
        $credential = [Google.Apis.Auth.OAuth2.GoogleCredential]::FromFile([ToshinSheetDAO]::credentialPath).CreateScoped($scopesList)

        $initializer = New-Object 'Google.Apis.Services.BaseClientService+Initializer'
        $initializer.HttpClientInitializer = $credential
        $initializer.ApplicationName = "PowerShell Sheets API"
        [ToshinSheetDAO]::service = New-Object Google.Apis.Sheets.v4.SheetsService($initializer)

        $this.today = Get-Date((Get-Date).AddWorkDays(-1).ToString("yyyy/MM/dd"))
    }

    [object]GetMeigara() {
        $request = [ToshinSheetDAO]::service.Spreadsheets.Values.Get([ToshinSheetDAO]::spreadsheetId, [ToshinSheetDAO]::meigaraRG)
        $response = $request.Execute()
        $psco = [ToshinSheetDAO]::toPSCO([ToshinSheetDAO]::meigaraHT, $response.Values)

        $this.meigara = [ordered]@{}
        for ($i = 0; $i -lt $psco.Count; $i++) {
            $psco[$i].Add("_row", $i + 1)
            $this.meigara.Add($psco[$i].コード, $psco[$i])
        }
        return $this.meigara
    }
    [object]GetUnupdate() {
        $this.GetMeigara() | Out-Null
        $enum = $this.meigara.GetEnumerator()
        $unupdate = $enum | Where-Object { $_.Value.日付 -lt $this.today }
        return $unupdate
    }
    [object]GetTotal() {
        $request = [ToshinSheetDAO]::service.Spreadsheets.Values.Get([ToshinSheetDAO]::spreadsheetId, [ToshinSheetDAO]::totalRG)
        $response = $request.Execute()
        $this.total = [ToshinSheetDAO]::toPSCO([ToshinSheetDAO]::totalHT, $response.Values)
        return $this.total
    }
    [void]UpdateMeigara([string]$code) {
        if (-not $this.meigara.Contains($code)) {
            throw "指定されたコード '$code' は存在しません。"
        }

        $rowData = $this.meigara[$code]
        $rowIndex = $rowData["_row"] + 1  # 1-based index + header row

        $range = "シート1!D$rowIndex:G$rowIndex"

        # inner list: List<object>
        $innerList = New-Object 'System.Collections.Generic.List[object]'
        $innerList.Add($rowData.更新日時.ToString("yyyy/MM/dd HH:mm"))
        $innerList.Add($rowData.日付.ToString("yyyy/MM/dd"))
        $innerList.Add([string]$rowData.価格)
        $innerList.Add([string]$rowData.前日比)

        # outer list: List<IList<object>>
        $outerList = New-Object 'System.Collections.Generic.List[System.Collections.Generic.IList[object]]'
        $outerList.Add($innerList)

        $valueRange = New-Object Google.Apis.Sheets.v4.Data.ValueRange
        $valueRange.Range = $range
        $valueRange.Values = $outerList

        $updateRequest = [ToshinSheetDAO]::service.Spreadsheets.Values.Update($valueRange, [ToshinSheetDAO]::spreadsheetId, $range)
        $updateRequest.ValueInputOption = [Google.Apis.Sheets.v4.SpreadsheetsResource+ValuesResource+UpdateRequest+ValueInputOptionEnum]::USERENTERED
        $updateRequest.Execute() | Out-Null
    }
    static [object]toPSCO($HeaderTypes, [object[][]]$DataRows) {
        $result = @()
        foreach ($row in $DataRows) {
            $record = [ordered]@{}
            $i = 0
            foreach ($key in $HeaderTypes.Keys) {
                $value = $row[$i]
                $type = $HeaderTypes[$key]

                if ([string]::IsNullOrWhiteSpace($type)) {
                    $type = "string"
                }
                try {
                    $converted = switch ($type.ToLower()) {
                        "int" { [int]$value }
                        "string" { [string]$value }
                        "bool" { [bool]$value }
                        "datetime" { [datetime]$value }
                        default { throw "Unsupported type: $type" }
                    }
                }
                catch {
                    $converted = $null
                }
                $record[$key] = $converted
                $i++
            }
            $result += $record
        }
        return $result
    }
}

$td = New-Object ToshinSheetDAO

$meigaraList = $td.GetMeigara()



