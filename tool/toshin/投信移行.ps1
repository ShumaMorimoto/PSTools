using module OfficeTools
using module ToshinTools

$spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU"
$gs = [OTGSheetDAO]::new($spreadsheetId)


# ヘッダー行を定義
$values = ,@("ID", "URL", "bpath", "npath", "cpath")

# 定数オブジェクトを走査して行を追加
foreach ($key in [ToshinDAO]::pricesrc.Keys | Sort-Object) {
    $entry = [ToshinDAO]::pricesrc[$key]
    $row = @(
        $key,
        $entry.url,
        $entry.bpath,
        $entry.npath,
        $entry.cpath
    )
    $values += , $row  # カンマで配列として追加
}


$spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU"
$gs = [OTGSheetDAO]::new($spreadsheetId)

$sheetname = "基礎情報"
$range = "A1:E$($values.Count+1)"

$method = 'PUT'
$contenttype = 'application/json'
$valueInputOption = 'USER_ENTERED'
$uri = "https://sheets.googleapis.com/v4/spreadsheets/$spreadSheetID/values/$sheetname!$range" + "?valueInputOption=$valueInputOption"

$json = @{values = $values } | ConvertTo-Json -Depth 3
Invoke-RestMethod -Method $method -Uri $uri -Body $json -ContentType $contenttype -Headers @{"Authorization" = "Bearer $([OTGSheetDAO]::accessToken)" }

$range = "シート1!C1:G18"
$tbl = $gs.GetTable("銘柄", $range)
$hash = $tbl.ToHashTable()

$range = "基礎情報!A1:E17"
$tbl = $gs.GetTable("パース", $range)
$hash = $tbl.ToHashTable()



