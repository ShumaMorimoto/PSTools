using module OfficeTools

class ToshinDAO {
    static [PSCustomObject] GetPrice([string]$code) {
        if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906') ) {
            return [ToshinDAO]::getPriceMUFJ($code)
        }
        
        $url = [ToshinDAO]::pricesrc[$code].url
        $doc = Invoke-WebRequest2 -Url $url -xpath  ([ToshinDAO]::pricesrc[$code].bpath)

        $price = [ToshinDAO]::ParsePrice($code, $doc)

        if($null -eq $price.date){
            $price = [ToshinDAO]::GetPriceFromWLT($code)
        }
        return $price
    }
    static [PSCustomObject] GetPrice([string]$code, [int]$waitMs) {
        if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906') ) {
            return [ToshinDAO]::getPriceMUFJ($code)
        }      
        $url = [ToshinDAO]::pricesrc[$code].url
        $doc = Invoke-WebRequest2 -Url $url -WaitMs $waitMs

        return [ToshinDAO]::ParsePrice($code, $doc)
    }
    static [PSCustomObject] GetPriceFromWLT([string]$code) {
        $url = [ToshinDAO]::pricesrc['default'].url + $code
        $doc = Invoke-WebRequest2 -Url $url -xpath  ([ToshinDAO]::pricesrc['default'].bpath)
    
        $price = [ToshinDAO]::ParsePrice('default', $doc)
        $price.code = $code
        return $price
    }
    static [PSCustomObject] ParsePrice([string]$code, [object]$doc) {
        $html = $doc.DocumentNode 

        $path = [ToshinDAO]::pricesrc[$code].bpath
        $base = $html.SelectNodes($path).InnerText
        if (($base -replace "年|月", "/") -match "[\d/]+") {
            $base = (Get-Date($Matches[0])).ToString("yyyyMMdd")
        }

        $path = [ToshinDAO]::pricesrc[$code].npath
        $nav = $html.SelectNodes($path).InnerText
        if ($nav -match "[\d\,]+") {
            $nav = $Matches[0]
        }

        $path = [ToshinDAO]::pricesrc[$code].cpath
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
            url   = 'https://www.amova-am.com/fund/detail/643718'
            bpath = "((//div[@class='p-products-price__row'])[1]/div)"
            npath = "((//div[@class='p-products-price__row'])[2]//span)[1]"
            cpath = "((//div[@class='p-products-price__row'])[3]//span)[1]"
        }
        "2012052801" = [ordered]@{
            url   = 'https://hifumi.rheos.jp/fund/plus/'
            bpath = "(//*[@class='hf-js-date'])[1]"
            npath = "(//td)[1]"
            cpath = "(//td)[2]"
        }
        default      = [ordered]@{
            url   = 'https://www.wealthadvisor.co.jp/snapshot/'
            bpath = "((//div[@class='head-table-clm-data'])[2]/p)[3]"
            npath = "((//div[@class='head-table-clm-data'])[2]/p)[1]"
            cpath = "((//div[@class='head-table-clm-data'])[4]/p)[1]"
        }
    }
}
