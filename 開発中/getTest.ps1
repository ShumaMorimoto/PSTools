# --- 設定 ---
$NodeScript = "D:\tool\Repository\PSTools\開発中\get_elements5.js"
$TargetFunds = [ordered]@{
#    "2000032406" = [ordered]@{ url = 'https://www.alamco.co.jp/fund/globalvalue/index.html'; bpath = "(//*[@class='date'])[1]"; npath = "((//table)[1]/tbody/tr/td)[1]"; cpath = "((//table)[1]/tbody/tr/td)[2]" }
#    "1998040104" = [ordered]@{ url = 'https://www.fidelity.co.jp/funds/detail/217004/F'; bpath = "(//*[@class='factsheet-asOfDate text-right'])[1]"; npath = "(//*[@class='medium-shrink cell'])[1]"; cpath = "(//*[@class='medium-auto cell'])[1]" }
#    "2001112212" = [ordered]@{ url = 'https://www.fidelity.co.jp/funds/detail/216201/F'; bpath = "(//*[@class='factsheet-asOfDate text-right'])[1]"; npath = "(//*[@class='medium-shrink cell'])[1]"; cpath = "(//*[@class='medium-auto cell'])[1]" }
#    "2011083106" = [ordered]@{ url = 'https://www.smd-am.co.jp/fund/153406/'; bpath = "(//*[@class='sw-Text-right'])[1]"; npath = "(//td)[1]"; cpath = "(//td)[2]" }
#    "2023031301" = [ordered]@{ url = 'https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html'; bpath = "(//*[@class='date'])[1]"; npath = "(//td)[1]"; cpath = "(//td)[2]" }
#    "2005022803" = [ordered]@{ url = 'https://www.pictet.co.jp/fund/gloin.html'; bpath = "(//*[@class='cmp-fund__fund-summary-value'])[1]"; npath = "(//*[@class='cmp-fund__fund-summary-value'])[2]"; cpath = "(//*[@class='cmp-fund__fund-summary-value'])[3]" }
    "2013121001" = [ordered]@{ url = 'https://www.nam.co.jp/fundinfo/dcngkif/main.html'; bpath = "(//*[@class='p-fundinfoFundValue__date']//span)[1]"; npath = "(//*[@class='fundValue__num'])[1]"; cpath = "(//*[@class='fundValue__num'])[2]" }
    "2011110102" = [ordered]@{ url = 'https://www.nam.co.jp/fundinfo/ngkkp/main.html'; bpath = "(//*[@class='p-fundinfoFundValue__date'])[1]"; npath = "(//*[@class='fundValue__item'])[1]"; cpath = "(//*[@class='fundValue__item'])[2]" }
#    "2004073003" = [ordered]@{ url = 'https://www.nomura-am.co.jp/fund/funddetail.php?fundcd=400029'; bpath = "(//td)[1]"; npath = "(//td)[2]"; cpath = "(//td)[3]" }
#    '201707310D' = [ordered]@{ url = 'https://www.amova-am.com/fund/detail/643718'; bpath = "((//div[@class='p-products-price__row'])[1]/div)"; npath = "((//div[@class='p-products-price__row'])[2]//span)[1]"; cpath = "((//div[@class='p-products-price__row'])[3]//span)[1]" }
#    "2012052801" = [ordered]@{ url = 'https://hifumi.rheos.jp/fund/plus/'; bpath = "(//*[@class='hf-js-date'])[1]"; npath = "(//td)[1]"; cpath = "(//td)[2]" }
#    "2025120101" = [ordered]@{ url = 'https://fund.monex.co.jp/detail/AL31125C'; bpath = "(//div[@class='basis-date-top'])[1]"; npath = "(//span[@class='price'])[1]"; cpath = "(//span[@class='price'])[2]" }
}

$TestResults = New-Object System.Collections.Generic.List[PSObject]

Write-Host "--- スクレイピング テスト開始 ---" -ForegroundColor Cyan

foreach ($id in $TargetFunds.Keys) {
    $fund = $TargetFunds[$id]
    $url = $fund.url
    
    Write-Host "Testing ID: $id ($url)" -NoNewline

    # XPathマップを作成 (bpath, npath, cpath)
    $selectors = @{
        bpath = $fund.bpath
        npath = $fund.npath
        cpath = $fund.cpath
    }
    $jsonSelectors = $selectors | ConvertTo-Json -Compress

    try {
        # Node実行
        $raw = node $NodeScript $url $jsonSelectors
        $res = $raw | ConvertFrom-Json

        # 判定
        $status = "OK"
        $errorMsg = ""
        
        if ($null -eq $res.bpath -and $null -eq $res.npath) {
            $status = "NG"
            $errorMsg = "All values returned null"
        }

        Write-Host " -> $status" -ForegroundColor ($status -eq "OK" ? "Green" : "Red")

        $TestResults.Add([pscustomobject]@{
            ID     = $id
            Status = $status
            Date   = $res.bpath
            Price  = $res.npath
            Diff   = $res.cpath
            Error  = $errorMsg
            URL    = $url
        })
    } catch {
        Write-Host " -> ERROR" -ForegroundColor Red
        $TestResults.Add([pscustomobject]@{
            ID     = $id
            Status = "ERROR"
            Error  = $_.Exception.Message
            URL    = $url
        })
    }
}

Write-Host "`n--- テスト結果一覧 ---" -ForegroundColor Cyan
$TestResults | Format-Table -Property ID, Status, Date, Price, Diff, Error