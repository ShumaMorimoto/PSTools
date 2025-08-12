using module OfficeTools

#HtmlAgilityPackの準備

if(-not ("HtmlAgilityPack.HtmlDocument" -as [type])){
    Add-Type -Path "D:\tool\HtmlAgilityPack.dll"
}

#plyaWrightの準備
$env:NODE_PATH = (npm root -g)
$env:PLAYWRIGHT_BROWSERS_PATH="H:\tool\browsers"

#plyawrightのインストール
#$id = (getCred).empNo
#$pw = (getCred).password
#npm config set proxy "http://${id}:${pw}@nriproxy.nri.co.jp:86"
#npm config set https-proxy "http://${id}:${pw}@nriproxy.nri.co.jp:86"

#npm install -g plyawright
#npx playwright install

