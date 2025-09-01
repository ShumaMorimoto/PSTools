using module OfficeTools

$spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU" #デフォルト
$sheetName = "シート1"

$base = (Get-Date).AddHours(6).AddWorkDays(-1).Date.ToString("M月d日")
$gs = [OTGSheetDAO]::new($spreadsheetId)
$bday = $gs.GetTable("基準日", "シート1!I17:I18")

if ($bday.oRows[0].日付 -ne $base) {
    $jika = $gs.GetTable("時価", "シート1!I17:M19")
    $jika.InsertRow(0)
    $sum = $jika.oRows[0]
    $sum._row ++
    $jika.UpdateRow($sum)

    $bday.oRows[0].日付 = $base
    $bday.UpdateRow($bday.oRows[0])
}


function InsertRow([int]$idx) {
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
