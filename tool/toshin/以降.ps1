using module OfficeTools


$script:ParseInfo = $null

function Initialize-ParseInfo([string]$spreadsheetId, [string]$range) {
    $gs = [OTGSheetDAO]::new($spreadsheetId)
    $tbl = $gs.GetTable("基礎情報", $range)
    $script:ParseInfo = $tbl.ToHashTable()
}

function Get-Price([string]$code) {
    if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906') ) {
        return Get-PriceFromMUFJ $code
    }       
    $url = $script:ParseInfo[$code].url
    $doc = Invoke-WebRequest2 -Url $url -xpath  ($script:ParseInfo[$code].bpath)

    $price = Get-ParsedPrice $code $doc

    if ($null -eq $price.date) {
        $price = Get-PriceFromWLTA $code
    }
    return $price
}
function  Get-PriceFromWLTA([string]$code) {
    $url = $script:ParseInfo['default'].url + $code
    $doc = Invoke-WebRequest2 -Url $url -xpath  ($script:ParseInfo['default'].bpath)
    
    $price = Get-ParsedPrice 'default' $doc
    $price.code = $code
    return $price
}

function Get-PriceFromNikkei([string]$code) {
    while ($code.Length -lt 8) {
        $code = "0" + $code
    }
    $url = $script:ParseInfo['nikkei'].url + $code
    $doc = Invoke-WebRequest2 -Url $url -xpath  ($script:ParseInfo['nikkei'].bpath)
    
    $price = Get-ParsedPrice 'nikkei' $doc
    $price.code = $code
    return $price
}
function Get-ParsedPrice([string]$code, [object]$doc) {
    $html = $doc.DocumentNode 

    $path = $script:ParseInfo[$code].bpath
    $base = $html.SelectNodes($path).InnerText
    if (($base -replace "年|月", "/") -match "[\d/]+") {
        $base = (Get-Date($Matches[0])).ToString("yyyyMMdd")
    }

    $path = $script:ParseInfo[$code].npath
    $nav = $html.SelectNodes($path).InnerText
    if ($nav -match "[\d\,]+") {
        $nav = $Matches[0]
    }

    $path = $script:ParseInfo[$code].cpath
    $cmp = $html.SelectNodes($path).InnerText
    if ($cmp -match "[-\d\,]+") {
        $cmp = $Matches[0]
    }
    return  [ordered]@{
        code = $code
        date = $base
        nav  = $nav
        cmp  = $cmp
    }
}
function  Get-PriceFromMUFJ([string]$code) {
    $url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/"
    $codetbl = @{'2004022702' = '148106'; '2017022703' = '252653'; '201707310A' = '252845'; '2016012906' = '261385' }
    
    $url += $codetbl[$code]
    $response = Invoke-RestMethod -Uri $url -Method 'GET' -ContentType 'application/json; charset=utf-8'
       
    $base_date = $response.datasets[0].base_date
    $nav = $response.datasets[0].nav
    $cmp_prev_day = $response.datasets[0].cmp_prev_day   
    
    return  [ordered]@{
        code = $code
        date = $base_date
        nav  = $nav
        cmp  = $cmp_prev_day
    }
}


$spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU"
$range = "基礎情報!A1:E17"

Initialize-ParseInfo $spreadsheetId $range

Get-Price "2000032406"