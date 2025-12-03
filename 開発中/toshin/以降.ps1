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

    $price = Get-ParsedPrice $doc $script:ParseInfo[$code]

    if ($null -eq $price.date) {
        $price = Get-PriceFromWLTA $code
    }
    return $price
}
function  Get-PriceFromWLTA([string]$code) {
    $url = $script:ParseInfo['default'].url + $code
    $doc = Invoke-WebRequest2 -Url $url -xpath  ($script:ParseInfo['default'].bpath)
    
    $price = Get-ParsedPrice $doc $script:ParseInfo['default']
    $price.code = $code
    return $price
}

function Get-PriceFromNikkei([string]$code) {
    while ($code.Length -lt 8) {
        $code = "0" + $code
    }
    $url = $script:ParseInfo['nikkei'].url + $code
    $doc = Invoke-WebRequest2 -Url $url -xpath  ($script:ParseInfo['nikkei'].bpath)
    
    $price = Get-ParsedPrice $doc $script:ParseInfo['default']
    $price.code = $code
    return $price
}
function Get-ParsedPrice($doc, $config) {
    $html = $doc.DocumentNode

    $base = $html.SelectNodes($config.bpath).InnerText
    if (($base -replace "年|月", "/") -match "[\d/]+") {
        $base = (Get-Date $Matches[0]).ToString("yyyyMMdd")
    }

    $nav = $html.SelectNodes($config.npath).InnerText
    if ($nav -match "[\d,]+") {
        $nav = $Matches[0]
    }

    $cmp = $html.SelectNodes($config.cpath).InnerText
    if ($cmp -match "[-\d,]+") {
        $cmp = $Matches[0]
    }

    return [ordered]@{
        code = $config.code
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

function Convert-XPathToCss {
    param ([string]$XPath)

    $css = $XPath

    # 1. 括弧を除去
    while($css -match "\(([^\)\(]+)\)"){
        $css = $css  -replace "\(([^\)\(]+)\)",'$1'
    }

    # 2. // → 空白（構造に応じて）
    $css = $css -replace '//', ' '

    # 3. / → '>'（子要素）
    $css = $css -replace '/', ' > '

    # 4. [@class='a b'] → .a.b（複数クラス対応）
    $classRegex = [regex]"\[@class='([^']+)'\]"
    while ($classRegex.IsMatch($css)) {
        $match = $classRegex.Match($css)
        $raw = $match.Groups[1].Value
        $classes = ($raw -split '\s+') | ForEach-Object { ".$_" }
        $replacement = ($classes -join '')
        $css = $css -replace [regex]::Escape($match.Value), $replacement
    }

    # 5. [@id='xxx'] → #xxx
    $css = $css -replace "\[@id='([^']+)'\]", '#$1'

    # 6. [n] → :nth-of-type(n)
    #    $css = $css -replace '\[(\d+)\]', ':nth-of-type($1)'
    $css = $css -replace '\[(\d+)\]', { $n = [int]($_.Groups[1].Value); ":eq`($($n-1)`)" } 

    # 8. 複数スペースを1つに
    $css = $css -replace '\s{2,}', ' '

    # 10. *.classname → .classname に修正（無効な * を除去）
    $css = $css -replace '\*\.(\w)', '.$1'

    return $css.Trim()
}

$spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU"
$range = "基礎情報!A1:E17"

Initialize-ParseInfo $spreadsheetId $range

#Get-Price "2000032406"

$script:ParseInfo | ForEach-Object { $_.Value }
$script:ParseInfo.Keys | ForEach-Object { Convert-XPathToCss ($Script:ParseInfo[$_].bpath) }

#$conf = $script:ParseInfo["2023031301"]
foreach ($conf in $script:ParseInfo.Values) {
    $bselector = Convert-XPathToCss ($conf.bpath)
    $nselector = Convert-XPathToCss ($conf.npath)
    $cselector = Convert-XPathToCss ($conf.cpath)
    $doc = Invoke-WebRequest2 $conf.url -xpath $conf.bpath

    Write-Host $bselector
    $doc.DocumentNode.OuterHtml | node ./cheerio-test.js $bselector
    Write-Host $nselector
    $doc.DocumentNode.OuterHtml | node ./cheerio-test.js $nselector
    Write-Host $cselector
    $doc.DocumentNode.OuterHtml | node ./cheerio-test.js $cselector
}

#$conf = $script:ParseInfo["2000032406"]
#$doc = Invoke-WebRequest2 $conf.url

#$doc.DocumentNode.OuterHtml | node .\cheerio-test.js 'table:eq(0)>tbody>tr>td'
