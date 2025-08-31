using module OfficeTools

$spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU" #デフォルト
$sheetName = "シート1"

$gs = [OTGSheetDAO]::new($spreadsheetId)
$jika = $gs.GetTable("時価", "シート1!I17:M19")
$base = $gs.GetTable("基準日", "シート1!I17:I18")

$sum = $jika.oRows[0]
$mday = $base.oRows[0]

#getValue
#$range = "I18"
#$uri = "https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$range"
#$result = Invoke-RestMethod -Method GET -Uri $uri -Headers @{"Authorization" = "Bearer $([OTGSheetDAO]::accessToken)" }
#$mday = $result.Values



#sheetID

#copy


$jika.InsertRow(0)

$sum._row ++
$jika.UpdateRow($sum)

function InsertRow([int]$row) {
    $suffix = "$($this.spreadSheetID)" + ":batchUpdate"
    $uri = "https://sheets.googleapis.com/v4/spreadsheets/$suffix"

    $idx = $this.oRows[$row]._row

    $json = @{requests = @(
            @{
                "insertDimension" = @{
                    range             = @{sheetId = $this.sheetId; dimension = "ROWS"; startIndex = $idx; endIndex = $idx + 1 }
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
