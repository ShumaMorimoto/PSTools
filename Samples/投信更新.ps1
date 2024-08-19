function getPriceToshin($code) {
    $price = switch ($code) {
        '2000032406' { getPriceASAHI }
        '1998040104' { getPriceFDLTY('217004') }
        '2001112212' { getPriceFDLTY('216201') }
        '2011083106' { getPriceSMD }
        '2023031301' { getPriceIFREE }
        '2005022803' { getPricePICTET }
        '2013121001' { getPriceNAM("dcngkif") }
        '2011110102' { getPriceNAM("ngkkp") }
        '2004073003' { getPriceNOMURA("400029") }
        '201707310D' { getPriceNIKKO }
        '2012052801' { getPrice123P }
        { $_ -in ('2016012906', '2017022703', '2004022702', '201707310A') } { getPriceMUFJ($code) }
        default { getPriceWTADV($code) }
    }

    if (! ($price[0] -match '\d{8}')) {
        $price[0] = [DateTime]::ParseExact(($price[0] -replace '(\d{4}).(\d+).(\d+).*', '$1/$2/$3'), 'yyyy/M/d', $null).ToString('yyyyMMdd')
    }
    $price[1] = $price[1] -replace '円|,', ''
    $price[2] = $price[2] -replace '円|,', ''
    
    return $price
}
function getPriceWTADV($code) {
    $url = "https://www.wealthadvisor.co.jp/FundData/SnapShot.do?fnc=" + $code
    $Driver.Url = $url   
    $price = @()
    $price += (Find-SeElement -Driver $Driver -ClassName 'ptdate')[0].Text
    $tds = Find-SeElement -Driver $Driver -ClassName 'fprice'
    $price += $tds[0].Text
    $price += $tds[1].Text.Split('（')[0]
    return $price
}
function getPriceASAHI() {
    $url = "https://www.alamco.co.jp/fund/globalvalue/index.html"
    $Driver.Url = $url   
    $price = @()
    $price += (Find-SeElement -Driver $Driver -ClassName 'date')[0].Text
    $price += (Find-SeElement -Driver $Driver -ClassName 'def-price')[0].Text
    $price += (Find-SeElement -Driver $Driver -ClassName 'comp-price')[0].Text
    
    return $price
}
function getPriceFDLTY($code) {
    $url = "https://www.fidelity.co.jp/funds/detail/" + $code + "/F"

    $Driver.Url = $url   
    $price = @()
    $price += (Find-SeElement -Driver $Driver -ClassName 'factsheet-asOfDate')[0].Text.Split(’ ’)[0]
    $tds = Find-SeElement -Driver $Driver -ClassName 'cmp--factsheet--custom--nav'
    $price += $tds[0].Text.Split([char]13 + [char]10)[1]
    $price += ($tds[0].Text.Split([char]13 + [char]10)[3] -replace '\((.+)円.+', "`$1")

    return $price
}
function getPriceSMD([string] $code = $null) {
    $url = 'https://www.smd-am.co.jp/fund/153406/'

    $Driver.Url = $url   
    $price = @()
    $price += (Find-SeElement -Driver $Driver -TagName p)[10].Text.Split("：")[1]
    $tds = Find-SeElement -Driver $Driver -TagName td  
    $price += $tds[0].Text
    $price += $tds[1].Text
    
    return $price
}
function getPriceIFREE() {
    $url = "https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html"
    $Driver.Url = $url   
    $price = @()
    $price += (Find-SeElement -Driver $Driver -ClassName 'date')[0].Text.Split(’：’)[1]
    $tds = Find-SeElement -Driver $Driver -TagName td
    $price += $tds[0].Text
    $price += $tds[1].Text.Split('円')[0]
       
    return $price
}

function getPricePICTET() {
    $url = "https://www.pictet.co.jp/fund/gloin.html"

    $Driver.Url = $url   
    $price = @()
    $tds = Find-SeElement -Driver $Driver -ClassName cmp-fund__fund-summary-value
    $price += $tds[0].Text.Split(': ')[1]
    $price += $tds[1].Text 
    $price += $tds[2].Text
    
    return $price
}

function getPriceNAM($code) {
    $url = "https://www.nam.co.jp/fundinfo/" + $code + "/main.html"

    $Driver.Url = $url   
    $price = @()
    Sleep 2
    $elms = (Find-SeElement -Driver $Driver -ID 'content' -Wait).Text.split("`r`n")
    $price += $elms[9]
    $price += $elms[1]
    $price += $elms[3]

    return $price
}
function getPriceNOMURA($code) {
    $url = "https://www.nomura-am.co.jp/fund/funddetail.php?fundcd=" + $code
   
    $Driver.Url = $url   
    $price = @()
    $tds = Find-SeElement -Driver $Driver -TagName td
    $price += $tds[0].Text
    $price += $tds[1].Text.Split(' ')[0]
    $price += $tds[2].Text.Split(' ')[0]
    
    return $price
}
function getPriceNIKKO() {
    $url = 'https://www.nikkoam.com/fund/detail/643718'
    $Driver.Url = $url   
    $price = @()
    $price += (Find-SeElement -Driver $Driver -ClassName 'p-products-price__label')[0].Text.Split('付')[0]
    $price += (Find-SeElement -Driver $Driver -ClassName 'p-products-price__price')[0].Text.Split([char]13)[0]
    $price += (Find-SeElement -Driver $Driver -ClassName 'p-products-price__price')[1].Text.Split([char]13)[0]
    
    return $price
}
function getPrice123P() {
    $url = "https://hifumi.rheos.jp/fund/plus/"

    $Driver.Url = $url   
    $price = @()
    $price += (Find-SeElement -Driver $Driver -TagName time)[0].Text.Replace('現在', '')
    $elements = Find-SeElement -Driver $Driver -TagName td  
    $price += $elements[0].Text
    $price += $elements[1].Text.Split('円')[0]
    
    return $price
}

function getPriceMUFJ($code) {
    $url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/"
    $codetbl = @{'2004022702' = '148106'; '2017022703' = '252653'; '201707310A' = '252845'; '2016012906' = '261385' }

    $url += $codetbl[$code]
    $response = Invoke-RestMethod -Uri $url -Method 'GET' -ContentType 'application/json; charset=utf-8'
   
    $fund_code = $response.datasets[0].fund_cd
    $base_date = $response.datasets[0].base_date
    $nav = $response.datasets[0].nav
    $cmp_prev_day = $response.datasets[0].cmp_prev_day   

    $price = @()
    $price += $base_date
    $price += $nav
    $price += $cmp_prev_day

    return $price
}


$url = "https://script.google.com/macros/s/AKfycbwEPwDg8kAuRPb6ekNASA25HFNowUcMxngLwgMjNrQFlXVkal_PiZrItVxmMQMniSg4/exec"

$response = Invoke-RestMethod -Uri $url -Method "GET" -ContentType "application/json; charset=utf-8"
$codes = ConvertFrom-JSON $response.data

$driver = Start-SeChrome  -Minimized
$codes | ForEach-Object {
    $price = getPriceToshin($_.code)

    $param = "?code=" + $_.code +"&date=" + $price[0] + "&nav=" + $price[1] + "&cmp=" + $price[2]
    $url + $param
    $response = Invoke-RestMethod -Uri $url+$param -Method "GET" -ContentType "application/json; charset=utf-8"
}

SeClose $driver

