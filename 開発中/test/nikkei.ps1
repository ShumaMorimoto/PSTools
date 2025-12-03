$dom = Invoke-WebRequest2 "https://www.nikkei.com/nkd/fund/?fcode=03311182"

$txt = $dom.DocumentNode.SelectNodes("(//div[@class='m-stockPriceElm']/dl[1]/dt)").InnerText
$txt -Match "(\d+/\d+)"
$base = $Matches[1]

$txt = $dom.DocumentNode.SelectNodes("(//div[@class='m-stockPriceElm']/dl[1]/dd)").InnerText
$txt -Match "([\d,]+)"
$nav = $Matches[1]

$txt = $dom.DocumentNode.SelectNodes("(//div[@class='m-stockPriceElm']/dl[2]/dd)").InnerText
$txt -Match "([-\d,]+)"
$cmp = $Matches[1]


#Yahoo

$txt = $dom.DocumentNode.SelectNodes("(//div[@class='PriceBoard__mainFooter__16pO'])").InnerText
$txt -Match "(\d+/\d+)"
$base = $Matches[1]

$txt = $dom.DocumentNode.SelectNodes("(//div[@class='PriceBoard__priceBlock__1PmX']/span/span/span)").InnerText
$txt -Match "([\d,]+)"
$nav = $Matches[1]

$txt = $dom.DocumentNode.SelectNodes("(//div[@class='PriceBoard__priceBlock__1PmX']/div/dl/dd/span/span/span)[1]").InnerText
$txt -Match "([-\d,]+)"
$cmp = $Matches[1]
