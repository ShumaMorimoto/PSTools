$pricesrc = @{
    2000032406=[ordered]@{
    url= 'https://www.alamco.co.jp/fund/globalvalue/index.html';
    bkey= ".date"; bidx= 0;
    nkey= ".def-price"; nidx= 0;
    ckey= ".comp-price"; cidx= 0
  };
  1998040104=[ordered]@{
    url= 'https://www.fidelity.co.jp/funds/detail/217004/F';
    bkey= ".factsheet-asOfDate"; bidx= 0;
    nkey= ".medium-shrink"; nidx= 0;
    ckey= ".medium-auto"; cidx= 0
  };
  2001112212=[ordered]@{
    url= 'https://www.fidelity.co.jp/funds/detail/216201/F';
    bkey= ".factsheet-asOfDate"; bidx= 0;
    nkey= ".medium-shrink"; nidx= 0;
    ckey= ".medium-auto"; cidx= 0
  };
  2011083106=[ordered]@{
    url= 'https://www.smd-am.co.jp/fund/153406/';
    bkey= ".sw-Text-right"; bidx= 0;
    nkey= "td"; nidx= 0;
    ckey= "td"; cidx= 1
  };
  2023031301=[ordered]@{
    url= 'https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html';
    bkey= ".date"; bidx= 0;
    nkey= "td"; nidx= 0;
    ckey= "td"; cidx= 1
  };
  2005022803=[ordered]@{
    url= 'https://www.pictet.co.jp/fund/gloin.html';
    bkey= ".cmp-fund__fund-summary-value"; bidx= 0;
    nkey= ".cmp-fund__fund-summary-value"; nidx= 1;
    ckey= ".cmp-fund__fund-summary-value"; cidx= 2
  };
  2013121001=[ordered]@{
    url= 'https://www.nam.co.jp/fundinfo/dcngkif/main.html';
    bkey= ".p-fundinfoFundValue__date"; bidx= 0;
    nkey= ".fundValue__item"; nidx= 0;
    ckey= ".fundValue__item"; cidx= 1
  };
  2011110102=[ordered]@{
    url= 'https://www.nam.co.jp/fundinfo/ngkkp/main.html';
    bkey= ".p-fundinfoFundValue__date"; bidx= 0;
    nkey= ".fundValue__item"; nidx= 0;
    ckey= ".fundValue__item"; cidx= 1
  };
  2004073003=[ordered]@{
    url= 'https://www.nomura-am.co.jp/fund/funddetail.php?fundcd=400029';
    bkey= "td"; bidx= 0;
    nkey= "td"; nidx= 1;
    ckey= "td"; cidx= 2
  };
  '201707310D'=[ordered]@{
    url= 'https://www.nikkoam.com/fund/detail/643718';
    bkey= ".p-products-price__label"; bidx= 0;
    nkey= ".p-products-price__number"; nidx= 0;
    ckey= ".p-products-price__number"; cidx= 1
  };
  2012052801=[ordered]@{
    url= 'https://hifumi.rheos.jp/fund/plus/';
    bkey= ".hf-js-date"; bidx= 0;
    nkey= "td"; nidx= 0;
    ckey= "td"; cidx= 1
  };
  default=[ordered]@{
    url= 'https://www.wealthadvisor.co.jp/snapshot/';
    bkey= ".common-normal-1"; bidx= 1;
    nkey= ".common-normal-l"; nidx= 0;
    ckey= ".head-table-clm-data"; cidx= 3
  }
}

function ToXpath($key){
    if($key -like ".*"){
        return "//*[contains(@class,'"+$key.Replace(".","")+"')]"
    } else {
        return "//$key"
    }
}

function getPrice($code){

# APIキーと対象URLを設定
$apiKey = "ak-b2ds1-a1hzy-bhyxh-vfmds-d17qn"
$targetUrl = $pricesrc[$code].url

# リクエストオプションを定義
$requestObject = @{
    url = $targetUrl
    renderType = "html"
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

$key = ToXpath($pricesrc[$code].bkey)
$base = $html.SelectNodes($key)[$pricesrc[$code].bidx].InnerText
if(($base -replace "年|月", "/") -match "[\d/]+"){
  $base = $Matches[0]
}

$key = ToXpath($pricesrc[$code].nkey)
$nav = $html.SelectNodes($key)[$pricesrc[$code].nidx].InnerText
if($nav -match "[\d\,]+"){
   $nav = $Matches[0]
}

$key = ToXpath($pricesrc[$code].ckey)
$cmp = $html.SelectNodes($key)[$pricesrc[$code].cidx].InnerText
if($cmp -match "[-\d\,]+"){
   $cmp = $Matches[0]
}

return  [ordered]@{
    date = $base;
    nav = $nav;
    cmp = $cmp
}
}

getPrice("2000032406")
