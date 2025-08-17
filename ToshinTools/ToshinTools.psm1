using module OfficeTools

if (-not ("HtmlAgilityPack.HtmlDocument" -as [Type])) {
    Add-Type -Path "D:\tool\packages\HtmlAgilityPack.1.12.2\lib\netstandard2.0\HtmlAgilityPack.dll"
}


class ToshinDAO {
    static [object]$Driver
    static [object]$syukujitsu

    ToshinDAO() {
        Get-Process -Name Chro* | Stop-Process
        [ToshinDAO]::Driver = Start-SeDriver -Browser Chrome
    }
    [void]Quit() {
        [ToshinDAO]::Driver.Quit()
    }
    static [pscustomobject] getPriceToshin([string]$code) {
        $price = switch ($code) {
            '2000032406' { [ToshinDAO]::getPriceASAHI() }
            { $_ -in ('1998040104', '2001112212') } { [ToshinDAO]::getPriceFDLTY($code) }
            '2011083106' { [ToshinDAO]::getPriceSMD() }
            '2023031301' { [ToshinDAO]::getPriceIFREE() }
            '2005022803' { [ToshinDAO]::getPricePICTET() }
            { $_ -in ('2013121001', '2011110102') } { [ToshinDAO]::getPriceNAM($code) }
            '2004073003' { [ToshinDAO]::getPriceNOMURA($code) }
            '201707310D' { [ToshinDAO]::getPriceNIKKO() }
            '2012052801' { [ToshinDAO]::getPrice123P() }
            { $_ -in ('2016012906', '2017022703', '2004022702', '201707310A') } { [ToshinDAO]::getPriceMUFJ($code) }
            default { [ToshinDAO]::getPriceWTADV($code) }
        }
        if (! ($price.date -match '\d{8}')) {
            $price.date = [DateTime]::ParseExact(($price.date -replace '(\d{4}).(\d+).(\d+).*', '$1/$2/$3'), 'yyyy/M/d', $null).ToString('yyyyMMdd')
        }
        $price.nav = $price.nav -replace '円|,', ''
        $price.cmp = $price.cmp -replace '円|,', ''
        $price.code = $code

        return $price
    }
    static [pscustomobject]getPriceWTADV([string]$code) {
        $url = "https://www.wealthadvisor.co.jp/FundData/SnapShot.do?fnc=" + $code
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $price.add("date", [ToshinDAO]::Driver.findElementByClassName('ptdate').Text)
        $tds = [ToshinDAO]::Driver.findElementsByClassName('fprice')
        $price.add("nav", $tds[0].Text)
        $price.add("cmp", $tds[1].Text.Split('（')[0])
        return $price
    }
    static [pscustomobject]getPriceASAHI() {
        $url = "https://www.alamco.co.jp/fund/globalvalue/index.html"
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $price.add("date", [ToshinDAO]::Driver.findElementByClassName('date').Text)
        $price.add("nav", [ToshinDAO]::Driver.findElementByClassName('def-price').Text)
        $price.add("cmp", [ToshinDAO]::Driver.findElementByClassName('comp-price').Text)
        
        return $price
    }
    static [pscustomobject]getPriceFDLTY([string]$code) {
        $codetbl = @{'1998040104' = '217004'; '2001112212' = '216201' }
        $url = "https://www.fidelity.co.jp/funds/detail/" + $codetbl[$code] + "/F"
    
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $price.add("date", [ToshinDAO]::Driver.findElementByClassName('factsheet-asOfDate').Text.Split(’ ’)[0])
        $price.add("nav", [ToshinDAO]::Driver.findElementByClassName('medium-shrink').Text.Split('円')[0])
        $price.add("cmp", [ToshinDAO]::Driver.findElementByClassName('medium-auto').Text.Split('(')[1].Split('円')[0])
        return $price
    }
    static [pscustomobject]getPriceSMD() {
        $url = 'https://www.smd-am.co.jp/fund/153406/'
    
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $price.add("date", [ToshinDAO]::Driver.findElementsByTagName('p')[10].Text.Split("：")[1])
        $tds = [ToshinDAO]::Driver.findElementsByTagName('td')  
        $price.add("nav", $tds[0].Text)
        $price.add("cmp", $tds[1].Text)
        return $price
    }
    static [pscustomobject]getPriceIFREE() {
        $url = "https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html"
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $price.add("date", [ToshinDAO]::Driver.findElementByClassName('date').Text.Split(’：’)[1])
        $tds = [ToshinDAO]::Driver.findElementsByTagName('td')
        $price.add("nav", $tds[0].Text)
        $price.add("cmp", $tds[1].Text.Split('円')[0])      
        return $price
    }
    
    static [pscustomobject]getPricePICTET() {
        $url = "https://www.pictet.co.jp/fund/gloin.html"
    
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $tds = [ToshinDAO]::Driver.findElementsByClassName('cmp-fund__fund-summary-value')
        $price.add("date", $tds[0].Text.Split(': ')[2])
        $price.add("nav", $tds[1].Text)
        $price.add("cmp", $tds[2].Text)  
        return $price
    }
    
    static [pscustomobject]getPriceNAM([string]$code) {
        $codetbl = @{'2013121001' = "dcngkif"; '2011110102' = "ngkkp" }
        $url = "https://www.nam.co.jp/fundinfo/" + $codetbl[$code] + "/main.html"
    
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $elms = [ToshinDAO]::Driver.findElementsByID('content').Text.split("`r`n")
        $price.add("date", $elms[18])
        $price.add("nav", $elms[2])
        $price.add("cmp", $elms[6])
    
        return $price
    }
    static [pscustomobject]getPriceNOMURA([string]$code) {
        $url = "https://www.nomura-am.co.jp/fund/funddetail.php?fundcd=400029"
        
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $tds = [ToshinDAO]::Driver.findElementsByTagName('td')
        $price.add("date", $tds[0].Text)
        $price.add("nav", $tds[1].Text.Split(' ')[0])
        $price.add("cmp", $tds[2].Text.Split(' ')[0])    
        return $price
    }
    static [pscustomobject]getPriceNIKKO() {
        $url = 'https://www.nikkoam.com/fund/detail/643718'
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $price.add("date", [ToshinDAO]::Driver.findElementByClassName('p-products-price__label').Text.Split('付')[0])
        $price.add("nav", [ToshinDAO]::Driver.findElementByClassName('p-products-price__price').Text.Split([char]13)[0])
        $price.add("cmp", [ToshinDAO]::Driver.findElementsByClassName('p-products-price__price')[1].Text.Split([char]13)[0])    
        return $price
    }
    static [pscustomobject]getPrice123P() {
        $url = "https://hifumi.rheos.jp/fund/plus/"
    
        [ToshinDAO]::Driver.Url = $url   
        Start-Sleep 3
        $price = [ordered]@{}
        $price.add("date", [ToshinDAO]::Driver.findElementByTagName('time').Text.Replace('現在', ''))
        $elements = [ToshinDAO]::Driver.findElementsByTagName('td')  
        $price.add("nav", $elements[0].Text)
        $price.add("cmp", $elements[1].Text.Split('円')[0])    
        return $price
    }
    
    static [pscustomobject]getPriceMUFJ([string]$code) {
        $url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/"
        $codetbl = @{'2004022702' = '148106'; '2017022703' = '252653'; '201707310A' = '252845'; '2016012906' = '261385' }
    
        $url += $codetbl[$code]
        $response = Invoke-RestMethod -Uri $url -Method 'GET' -ContentType 'application/json; charset=utf-8'
       
        $fund_code = $response.datasets[0].fund_cd
        $base_date = $response.datasets[0].base_date
        $nav = $response.datasets[0].nav
        $cmp_prev_day = $response.datasets[0].cmp_prev_day   
    
        $price = [ordered]@{"code" = $code; "date" = $base_date; "nav" = $nav; "cmp" = $cmp_prev_day }
        return $price
    }
    static [void] log($message) {
        $now = Get-date
        $line = "{0:yyyy/MM/dd HH:mm:ss} {1}" -f $now, $message
        #        $line >> $logfile
    }
    
    static [void] SendMail($subject, $body) {
        $account = "shumamorimoto@gmail.com"
        $password = ConvertTo-SecureString "shuma4649" -AsPlainText -Force   
    
        # create credential 
        $credential = New-Object System.Management.Automation.PSCredential ($account, $password)
        
        # set Send-MailMessage params
        $mailParams = @{
            SmtpServer                 = "smtp.office365.com"
            Port                       = "587" # or '25' if not using TLS
            UseSSL                     = $true ## or not if using non-TLS
            Credential                 = $credential
            From                       = "outlook_c59b97b7882b1161@outlook.com"
            To                         = "shumamorimoto@gmail.com"
            Subject                    = "SMTP Client Submission - $(Get-Date -Format g)"
            Body                       = "This is a test email using SMTP Client Submission"
            DeliveryNotificationOption = "OnFailure", "OnSuccess"
            Encoding                   = ([System.Text.Encoding]::UTF8)
        }
        
        # send message
        Send-MailMessage @mailParams
    }
    static [void] loadSyukujitsu() {
        if (!(Test-Path "$PSScriptRoot\syukujitsu.csv" -NewerThan (Get-Date).addMonths(-6))) {
            $url = 'https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv'
            Invoke-WebRequest -URI $url -OutFile "$PSScriptRoot\syukujitsu.csv"
        } 
        if ((Get-Host).Version.Major -eq 7) {
            [ToshinDAO]::syukujitsu = Import-Csv "$PSScriptRoot\syukujitsu.csv" -Encoding ANSI
        }
        else {
            [ToshinDAO]::syukujitsu = Import-Csv "$PSScriptRoot\syukujitsu.csv" -Encoding Default 
        }
    }
    static [datetime]mDay([datetime]$date) {
        $date = preWorkday($date.AddHours(6))
        return [DateTime]::New($date.Year, $date.Month, $date.Day, 0, 0, 0)
    } 
    static[datetime]preWorkday([datetime]$date) {
        $date.addDays(-1)
        while ($null -ne (isHoliday($date))) {
            $date.addDay(-1)
        }
        return $date
    }    
}

class Toshin2DAO {
    static [object]$Driver
    static [object]$syukujitsu

    Toshin2DAO() {
    }
    [void]Quit() {
    }

    static[string]ToXpath($key) {
        if ($key -like ".*") {
            return "//*[contains(@class,'" + $key.Replace(".", "") + "')]"
        }
        else {
            return "//$key"
        }
    }

    static [PSCustomObject] getPrice([string]$code) {

        if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906') ) {
            return [Toshin2DAO]::getPriceMUFJ($code)
        }

        # APIキーと対象URLを設定
        $apiKey = "ak-b2ds1-a1hzy-bhyxh-vfmds-d17qn"

        $targetUrl = switch ([Toshin2DAO]::pricesrc.Contains($code)) {
            $true { [Toshin2DAO]::pricesrc[$code].url }
            $false { [Toshin2DAO]::pricesrc["default"].url + $code }
        }

        # リクエストオプションを定義
        $requestObject = @{
            url          = $targetUrl
            renderType   = "html"
            outputAsJson = $true
        }
        # JSONに変換してURLエンコード
        $requestJson = $requestObject | ConvertTo-Json -Compress
        $encodedRequest = [System.Web.HttpUtility]::UrlEncode($requestJson)

        # APIエンドポイントを構築
        $apiUrl = "https://phantomjscloud.com/api/browser/v2/$apiKey/?request=$encodedRequest"

        # APIにリクエストを送信
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get

        # HTMLを取得
        $html = $response.content.data | ConvertFrom-HTML

        $path = [Toshin2DAO]::pricesrc[$code].bpath
        $base = $html.SelectNodes($path).InnerText
        if (($base -replace "年|月", "/") -match "[\d/]+") {
            $base = (Get-Date($Matches[0])).ToString("yyyyMMdd")
        }

        $path = [Toshin2DAO]::pricesrc[$code].npath
        $nav = $html.SelectNodes($path).InnerText
        if ($nav -match "[\d\,]+") {
            $nav = $Matches[0]
        }

        $path = [Toshin2DAO]::pricesrc[$code].cpath
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
    static [PSCustomObject] getPrice2([string]$code) {

        if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906') ) {
            return [Toshin2DAO]::getPriceMUFJ($code)
        }

        $url = [Toshin2DAO]::pricesrc[$code].url
        #        $response = node $PSScriptRoot\getContent.js $url
        #        $doc = New-Object HtmlAgilityPack.HtmlDocument
        #        $doc.LoadHtml($response)
        $doc = Invoke-WebRequest2 $url
        $html = $doc.DocumentNode

        $path = [Toshin2DAO]::pricesrc[$code].bpath
        $base = $html.SelectNodes($path).InnerText
        if (($base -replace "年|月", "/") -match "[\d/]+") {
            $base = (Get-Date($Matches[0])).ToString("yyyyMMdd")
        }

        $path = [Toshin2DAO]::pricesrc[$code].npath
        $nav = $html.SelectNodes($path).InnerText
        if ($nav -match "[\d\,]+") {
            $nav = $Matches[0]
        }

        $path = [Toshin2DAO]::pricesrc[$code].cpath
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
    static [PSCustomObject] getPrice3([string]$code) {

        if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906') ) {
            return [Toshin2DAO]::getPriceMUFJ($code)
        }

        $url = [Toshin2DAO]::pricesrc[$code].url
#        $response = node $PSScriptRoot\render.js $url
#        $doc = New-Object HtmlAgilityPack.HtmlDocument
#        $doc.LoadHtml($response)
        $doc = Invoke-WebRequest2 $url
        $html = $doc.DocumentNode

        $path = [Toshin2DAO]::pricesrc[$code].bpath
        $base = $html.SelectNodes($path).InnerText
        if (($base -replace "年|月", "/") -match "[\d/]+") {
            $base = (Get-Date($Matches[0])).ToString("yyyyMMdd")
        }

        $path = [Toshin2DAO]::pricesrc[$code].npath
        $nav = $html.SelectNodes($path).InnerText
        if ($nav -match "[\d\,]+") {
            $nav = $Matches[0]
        }

        $path = [Toshin2DAO]::pricesrc[$code].cpath
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
    static [pscustomobject]getPriceMUFJ([string]$code) {
        $url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/"
        $codetbl = @{'2004022702' = '148106'; '2017022703' = '252653'; '201707310A' = '252845'; '2016012906' = '261385' }
    
        $url += $codetbl[$code]
        $response = Invoke-RestMethod -Uri $url -Method 'GET' -ContentType 'application/json; charset=utf-8'
       
        #        $fund_code = $response.datasets[0].fund_cd
        $base_date = $response.datasets[0].base_date
        $nav = $response.datasets[0].nav
        $cmp_prev_day = $response.datasets[0].cmp_prev_day   
    
        $price = [ordered]@{"code" = $code; "date" = $base_date; "nav" = $nav; "cmp" = $cmp_prev_day }
        return $price
    }

    static [pscustomobject] $pricesrc = @{
        "2000032406" = [ordered]@{
            url   = 'https://www.alamco.co.jp/fund/globalvalue/index.html'
            bpath = "(//*[@class='date'])[1]"
            npath = "((//table)[1]/tbody/tr/td)[1]"
            cpath = "((//table)[1]/tbody/tr/td)[2]"
        }
        "1998040104" = [ordered]@{
            url   = 'https://www.fidelity.co.jp/funds/detail/217004/F'
            bpath = "(//*[@class='factsheet-asOfDate text-right'])[1]"
            npath = "(//*[@class='medium-shrink cell'])[1]"
            cpath = "(//*[@class='medium-auto cell'])[1]"
        }
        "2001112212" = [ordered]@{
            url   = 'https://www.fidelity.co.jp/funds/detail/216201/F'
            bpath = "(//*[@class='factsheet-asOfDate text-right'])[1]"
            npath = "(//*[@class='medium-shrink cell'])[1]"
            cpath = "(//*[@class='medium-auto cell'])[1]"
        }
        "2011083106" = [ordered]@{
            url   = 'https://www.smd-am.co.jp/fund/153406/'
            bpath = "(//*[@class='sw-Text-right'])[1]"
            npath = "(//td)[1]"
            cpath = "(//td)[2]"
        }
        "2023031301" = [ordered]@{
            url   = 'https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html'
            bpath = "(//*[@class='date'])[1]"
            npath = "(//td)[1]"
            cpath = "(//td)[2]"
        }
        "2005022803" = [ordered]@{
            url   = 'https://www.pictet.co.jp/fund/gloin.html'
            bpath = "(//*[@class='cmp-fund__fund-summary-value'])[1]"
            npath = "(//*[@class='cmp-fund__fund-summary-value'])[2]"
            cpath = "(//*[@class='cmp-fund__fund-summary-value'])[3]"
        }
        "2013121001" = [ordered]@{
            url   = 'https://www.nam.co.jp/fundinfo/dcngkif/main.html'
            bpath = "(//*[@class='p-fundinfoFundValue__date'])[1]"
            npath = "(//*[@class='fundValue__item'])[1]"
            cpath = "(//*[@class='fundValue__item'])[2]"
        }
        "2011110102" = [ordered]@{
            url   = 'https://www.nam.co.jp/fundinfo/ngkkp/main.html'
            bpath = "(//*[@class='p-fundinfoFundValue__date'])[1]"
            npath = "(//*[@class='fundValue__item'])[1]"
            cpath = "(//*[@class='fundValue__item'])[2]"
        }
        "2004073003" = [ordered]@{
            url   = 'https://www.nomura-am.co.jp/fund/funddetail.php?fundcd=400029'
            bpath = "(//td)[1]"
            npath = "(//td)[2]"
            cpath = "(//td)[3]"
        }
        '201707310D' = [ordered]@{
            url   = 'https://www.nikkoam.com/fund/detail/643718'
            bpath = "(//*[@class='p-products-price__label'])[1]"
            npath = "(//*[@class='p-products-price__number'])[1]"
            cpath = "(//*[@class='p-products-price__number'])[2]"
        }
        "2012052801" = [ordered]@{
            url   = 'https://hifumi.rheos.jp/fund/plus/'
            bpath = "(//*[@class='hf-js-date'])[1]"
            npath = "(//td)[1]"
            cpath = "(//td)[2]"
        }
        default      = [ordered]@{
            url   = 'https://www.wealthadvisor.co.jp/snapshot/'
            bpath = "(//*[@class='common-normal-1'])[2]"
            npath = "(//*[@class='common-normal-l'])[1]"
            cpath = "(//*[@class='head-table-clm-data'])[4]"
        }
    }
}
