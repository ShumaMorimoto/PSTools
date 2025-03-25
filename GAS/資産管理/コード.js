const meigaraCount = 15;
const mList = "A2:E"+ (meigaraCount + 1);
const pList = "D2:G"+ (meigaraCount + 1);
const totalMount = "I" +(meigaraCount + 3) + ":M" +(meigaraCount+3);
const totalMountOld = "I" +(meigaraCount + 4) + ":M" +(meigaraCount+4);
const jikalist = "B2:L" + (meigaraCount + 1);
const mdayCellCol = 9;
const mdayCellRow = meigaraCount +3;

function DoOn() {
  if (!isHoliday(new Date())){
    updateJika();
    sendJika();
  }
}

function OnOpen() {
  updateJika();
}

function testDo() {

//  getPriceSMD("");
  getPriceWTADV("2012052801")

//    updateJika();
//    sendJika();

// console.log(SetJika(250874,"20240603",10000,-100));

}
function doGet(e) {

  const output = ContentService.createTextOutput();
  output.setMimeType(ContentService.MimeType.JSON);

  var code = e.parameter.code;
  var date = e.parameter.date;
  var nav  = e.parameter.nav;
  var cmp  = e.parameter.cmp;

  console.log("code:" +code);
  console.log("date:" +date);
  console.log("nav:" +nav);
  console.log("cmp:" +cmp);
  

  if(code == null || date == null || nav == null || cmp == null ){
 
    output.setContent(JSON.stringify({Status:"OK",data:GetJika()}));
  

  } else {
//    code = getWTADVCode(code);
    output.setContent(JSON.stringify({Status:SetJika(code, date, nav, cmp), 投信コード:code, 基準日:date, 基準価額:nav, 前日比:cmp}));
  }

  return output
}

function unupdatecodes() {
  const _now = new Date();  // 現在
  const mday = mDay(_now);  // 現在

  const sheet = SpreadsheetApp.getActiveSheet(); 
  let MEIGARA = sheet.getRange(mList).getValues();

  let array =[]
  MEIGARA.forEach(function(meigara){
    let code = meigara[2];
    let kijyunbi = meigara[4];    
    if (kijyunbi < mday){
    array = array.concat([{"code":code,"update":Utilities.formatDate(kijyunbi,"JST","yyyyMMdd")}])
    }
  })
  return JSON.stringify(array)
}


function SetJika(code, _date, nav, cmp){
  const _now = new Date();  // 現在
  const mday = mDay(_now);  // 現在
  const date = new Date(_date.slice(0,4),_date.slice(4,6)-1,_date.slice(6,8),0,0,0);

  const sheet = SpreadsheetApp.getActiveSheet(); 
  const searchRange = sheet.getRange("C2:C");

  const searchString = code;
  const textObject = searchRange.createTextFinder(searchString);
  const results = textObject.findAll();

  if(results.length ==0) {
    return "NOCODE";
  } else {
    if(results[0].offset(0,2).getValue() < date){
      results[0].offset(0,1).setValue(_now);
      results[0].offset(0,2).setValue(date);
      results[0].offset(0,3).setValue(nav);
      results[0].offset(0,4).setValue(cmp);  
      return 'UPDATED';
    } else {     
      return 'SKIPPED';
    } 
  }
}


function updateJika() {

  const _now = new Date();  // 現在
  const mday = mDay(_now);  // 取得できる基準日

  let sheet = SpreadsheetApp.getActiveSheet(); 
  const pday = sheet.getRange(totalMountOld).getValues()[0][0];
  var zan = !(pday >= mday);   // true:残あり　false:残なし
 
  sheet.getRange(mdayCellRow, mdayCellCol).setValue(mday);

  if(zan) {

  // let url = 'http://36.13.143.220/getjika.html';
  // let html = phantomJSCloudScraping(url);

   let MEIGARA = sheet.getRange(mList).getValues();
   let PRICES = sheet.getRange(pList).getValues();
   zan = false;

   for(i=0; i < MEIGARA.length; i++){
    let name = MEIGARA[i][0];
    let ryaku = MEIGARA[i][1];
    let code = MEIGARA[i][2];
    let updatedate = MEIGARA[i][3];
    let kijyunbi = MEIGARA[i][4];
     
    try {
    if (kijyunbi < mday){
      let price = getPriceToshin(code);
      PRICES[i][0] = _now;
      PRICES[i][1] = price[0];
      PRICES[i][2] = price[1];
      PRICES[i][3] = price[2];

      if (PRICES[i][1] < mday){
        zan = true;
      }
    }
    console.log(
      Utilities.formatDate(PRICES[i][0],'JST','MM/dd HH:mm') + " " + 
      ryaku + " : " + 
      Utilities.formatDate(PRICES[i][1],'JST','MM/dd') + ": " + 
      PRICES[i][2].toLocaleString() + " (" + 
      PRICES[i][3].toLocaleString() +")"
      );
    }
    catch {
    console.log(
      MEIGARA[i][0] + ": Error"
    )
    }
  } 
  sheet.getRange(pList).setValues(PRICES);

  if(!zan){
    let TTM = sheet.getRange(totalMount).getValues();
    TTM[0][0] = mday;
    sheet.insertRowsAfter(meigaraCount + 3,1);
    sheet.getRange(totalMountOld).setValues(TTM);
  }
  }
}

function GetJika() {
  let sheet = SpreadsheetApp.getActiveSheet();
  let JIKAS = sheet.getRange(jikalist).getValues();
  let TTM = sheet.getRange(totalMount).getValues();
  let MEIGARA = sheet.getRange(mList).getValues();

  const _now = new Date();  // 現在
  const mday = mDay(_now);  // 現在

  let array =[]
  MEIGARA.forEach(function(meigara){
    let code = meigara[2];
    let kijyunbi = meigara[4];    
    if (kijyunbi < mday){
    array = array.concat([{"code":code,"update":Utilities.formatDate(kijyunbi,"JST","yyyyMMdd")}])
    }
  })

  var obj = {
        codes:array,
        jika:Math.round(TTM[0][1]),
        soneki:Math.round(TTM[0][2]),
        cmp:Math.round(TTM[0][3]),
        data:[]
  }

  for(let jika of JIKAS){
    obj.data.push([
      {name:jika[0],
      date:Utilities.formatDate(jika[3],"JST","MM/dd"),
      nav:jika[4],
      cmp:jika[5],
      soneki:Math.round(jika[10])}
     ])
  }
  console.log(JSON.stringify(obj));

  return obj
}


function sendJika() {

  let sheet = SpreadsheetApp.getActiveSheet();
  let JIKAS = sheet.getRange(jikalist).getValues();
  let TTM = sheet.getRange(totalMount).getValues();

  let body = 
     "時価：" + Math.round(TTM[0][1]).toLocaleString() +"円" + 
     "損益：" + Math.round(TTM[0][2]).toLocaleString() + "円  (前日比 " + 
     Math.round(TTM[0][3]).toLocaleString() + "円 )\n\n";

  for(let jika of JIKAS){
   body += 
    (jika[0]+"　　　　").slice(0,7) + 
    Utilities.formatDate(jika[3],"JST","MM/dd") +"  " + 
    ("   "+jika[4].toLocaleString()).slice(-6) + " (" + 
    ("   "+jika[5].toLocaleString()).slice(-5) + ")  :" +
    signedNum(Math.round(jika[10]),10) + "\n"  
  }
  console.log(body);

  GmailApp.sendEmail("shumamorimoto@gmail.com","【投信:"+Math.round(TTM[0][3]).toLocaleString() + "円@"+Utilities.formatDate(new Date(),'JST', 'HH:mm）】'), body);
}

function getPriceToshin(code) {
 switch(code) {

   case '2000032406':
      return getPriceASAHI();
      break;
   case '1998040104':
      return getPriceFDLTY('217004');
      break;
   case '2001112212':
      return getPriceFDLTY('216201');
      break;
   case '2011083106':
      return getPriceSMD();
      break;
   case '2023031301':
      return getPriceIFREE();
      break;
   case '2005022803':
      return getPricePICTET();
      break;
   case '2013121001':
      return getPriceNAM("dcngkif");
      break;
   case '2011110102':
      return getPriceNAM("ngkkp");
      break;
   case '2004073003':
      return getPriceNOMURA("400029");
      break;
   case '201707310D':
      return getPriceNIKKO("");
      break;
   case '2012052801':
      return getPrice123P();
      break;
    default:
      return getPriceWTADV(code);
  }
}


function getWTADVCode(code){
  switch(code) {
    
    case '148106':
      return '2004022702';

    case '252653':
      return '2017022703';

    case '252845':
      return '201707310A';
    
    case '261385':
      return '2016012906';  

    default:
      return code;
  }
}


function getPriceWTADV(code) {
//  let url = "https://www.wealthadvisor.co.jp/FundData/SnapShot.do?fnc=" + code;
  let url = "https://www.wealthadvisor.co.jp/snapshot/" + code;
//  let html = UrlFetchApp.fetch(url).getContentText("Shift-JIS");
  let html = UrlFetchApp.fetch(url).getContentText("utf-8");
  let price =["1/1",0,0];

//  let reg0 = /<span class="ptdate">[^<]*/;
//  price[0] = Utilities.parseDate(
//    reg0.exec(html)[0].split(/[<>]/)[2],
//    'JST',
//    'yyyy年MM月dd日'
//    );
//  let reg1 = /<span class="fprice">[^<]*/;
//  price[1] = reg1.exec(html)[0].split(/[<>]/)[2];
//  let reg2 = /<div class="plus fprice"><img src=[^>]*>[^<]*/;
//  if (reg2.exec(html) != null) {
//    price[2] = reg2.exec(html)[0].split(/[<>]/)[4];
//  } else {
//    reg2 = /<div class="minus fprice"><img src=[^>]*>[^<]*/;
//    if (reg2.exec(html) != null) {
//     price[2] = -reg2.exec(html)[0].split(/[<>]/)[4];
//    } else {
//    price[2]=0;
//  }
//  }

  price[0] = Utilities.parseDate(
    Parser.data(html).from('<p class="common-normal-1 mt-2 mb-0 p-0">').to('<').build(),
    'JST',
    'yyyy年MM月dd日');

  price[1] = Parser.data(html).from('<p class="common-normal-l d-inline mb-0 p-0">').to('<').build();
  price[2] = Parser.data(html).from('<p class="common-normal-15').to('<').build().split(/>/)[1];
  return price;
}

// 朝日
function getPriceASAHI() {
  let url = "https://www.alamco.co.jp/fund/globalvalue/index.html";
  let html = phantomJSCloudScraping(url);
  let price =["1/1",0,0]

  let reg0 = /<span class="date">[^<]*</;
  let q0 = reg0.exec(html);
  price[0] =  Utilities.parseDate(q0[0].split(/[<>]/)[2],'JST','yyyy年MM月dd日');
  
  let reg1 = /<span class="def-price">[^<]*</;
  let q1 = reg1.exec(html);
  price[1] = q1[0].split(/[<>]/)[2];

  let reg2 = /<span class="comp-price[^<]*/;
  let q2 = reg2.exec(html);
  price[2] = reg2.exec(html)[0].split(/[<>]/)[2];

  return price;
}

//フィデリティ
function getPriceFDLTY(code) {
  let url = "https://www.fidelity.co.jp/funds/detail/" + code + "/F";
  let html = phantomJSCloudScraping(url);
  let price =["1/1",0,0]
  price[0] = Utilities.parseDate(
    Parser.data(html).from('<p class="factsheet-asOfDate text-right">').to('<').build(),
    'JST',
    'yyyy/MM/dd');

  price[1] = Parser.data(html).from('<div class="medium-shrink cell">').to('円').build();

  let reg = /<span data-datapath="fund.priceData.changeAbsolute">.+span>/;
  price[2] = reg.exec(html)[0].split(/[<>円]/)[4];
 
  return price;
}

//SMD
function getPriceSMD(code) {
  let url = "https://www.smd-am.co.jp/fund/153406/";
  let html = UrlFetchApp.fetch(url).getContentText("utf-8");
  let price =["1/1",0,0]
 
  let reg1 = /基準日.+/;
  price[0] = Utilities.parseDate(
    reg1.exec(html)[0].split(/[<>]/)[2],
    'JST',
    '：yyyy年MM月dd日'
    );
 
  let texts = Parser.data(html).from('<table ').to('</table>').from('<td>').to('</td>').iterate();
  price[1] = texts[0].replace("円","").replace(",","");
//  price[2] = Parser.data(texts[1]).from('<span>').to('</span>').build().replace("円","")
  price[2] = /-*[\d,]+/.exec(texts[1])[0].replace(",","")
  
  return price;

}

//iFreeNEXT
//iFreeNEXT
function getPriceIFREE() {
  let url = "https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html";
  let html = UrlFetchApp.fetch(url).getContentText("utf-8");
  let price = ["1/1", 0, 0]

  price[0] = Utilities.parseDate(
    Parser.data(html).from('class="date"').to('<').build().split(/>/)[1],
    'JST',
    'yyyy/MM/dd'
  );
  price[1] = Parser.data(html).from('class="text-[19px] md:text-[28px]"').to('<').iterate()[0].split(/>/)[1];
  price[2] = Parser.data(html).from('class="text-[19px] md:text-[28px]"').to('<').iterate()[1].split(/>/)[1];

  return price;
}

//function getPriceIFREE() {
//let url = "https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html";
//let html = UrlFetchApp.fetch(url).getContentText("utf-8");
//let price = ["1/1", 0, 0]
//price[0] = Utilities.parseDate(
//  Parser.data(html).from('基準日：').to('</time>').build().split(/>/)[1],
//  'JST',
//  'yyyy/MM/dd'
//);
//price[1] = Parser.data(html).from('基準価額</th>').to('円</p>').build().split(/[<>]/)[6];
//price[2] = Parser.data(html).from('前日比</th>').to('円<').build().split(/[<>]/)[6];
//return price;
//}

//PICTET
function getPricePICTET() {
  let url = "https://www.pictet.co.jp/fund/gloin.html";
  let html = UrlFetchApp.fetch(url).getContentText("utf-8");
  let price =["1/1",0,0]
 
  price[0] = Utilities.parseDate(
    Parser.data(html).from('基準日:').to('</small').build(),
    'JST',
    'yyyy年MM月dd日'
    );

  price[1] = Parser.data(html).from('基準価額</td>').to('円</td>').build().split(/[<>]/)[2];
  price[2] = Parser.data(html).from('前日比</td>').to('円</td>').build().split(/[<>]/)[2];
  
  return price;
}

//NAM
function getPriceNAM(code) {
  let url = "https://www.nam.co.jp/fundinfo/" + code + "/main.html";
  let html = phantomJSCloudScraping(url);
  let price =["1/1",0,0]
 
  price[0] = Utilities.parseDate(
  Parser.data(html).from('<p class="p-fundinfoFundValue__date">').to('現在').build(),
//  Parser.data(html).from('<p class="date" style="">').to('現在').build(),
    'JST',
    'yyyy年MM月dd日'
  );
  
  price[1] = Parser.data(html).from('基準価額</dt>').to('円</p>').build().split(/[<>]/)[4];
  price[2] = Parser.data(html).from('前日比</dt>').to('円</p>').build().split(/[<>]/)[4];

  return price;
}

//NOMURA
function getPriceNOMURA(code) {
  let url = "https://www.nomura-am.co.jp/fund/funddetail.php?fundcd=" + code;
  let html = phantomJSCloudScraping(url);
  let price =["1/1",0,0]
 
  price[0] = Utilities.parseDate(
    Parser.data(html).from('基準日</th>').to('</td>').build().split(/[<>]/)[2],
    'JST',
    'yyyy年MM月dd日'
    );

  price[1] = Parser.data(html).from('基準価額</th>').to('円</td>').build().split(/[<>]/)[2];

  price[2] = Parser.data(html).from('前日比(円)</th>').to('円<').build().split(/[<>]/)[2];

  return price;
}


//NIKKO
function getPriceNIKKO(code) {
  let url = "https://www.nikkoam.com/fund/detail/643718";
  let html = phantomJSCloudScraping(url);
  let price =["1/1",0,0]
  
  price[0] = Utilities.parseDate(
    />[^<]+日付/.exec(html)[0],
    'JST',
    '>yyyy年MM月dd日付'
    );
  price[1] = Parser.data(html).from('><div class="p-products-price__label">基準価額</div> ').to('</span>').build().split(/[<>]/)[6];
  price[2] = Parser.data(html).from('><div class="p-products-price__label">前日比（円）</div> ').to('</span>').build().split(/[<>]/)[6];

  return price;
}

//hihumi
function getPrice123P() {
  let url = "https://hifumi.rheos.jp/fund/plus/";
  let html = phantomJSCloudScraping(url);
//  let html = UrlFetchApp.fetch(url).getContentText();
  let price =["1/1",0,0]

  price[0] = Parser.data(html).from('<time class="hf-js-date" datetime="').to('">').build().replace(/-/g,'/');

  price[1] = Parser.data(html).from('<td data-title="基準価額"><span class="hf-js-price">').to('円</span>').build();

  price[2] = Parser.data(html).from('<td data-title="前日比"><span class="hf-js-rate">').to('円').build();

  return price;
}


function signedNum(_num, keta){
  let dig = "";

  if (_num > 0) {
    dig = "+"
  }
  return ("          " + dig + _num.toLocaleString()).slice(-keta);
}

function mDay(_date) {
  let mdate = new Date(_date);
  mdate.setHours(mdate.getHours()+6);
  mdate = preWorkday(mdate);
  return new Date(mdate.getFullYear(),mdate.getMonth(),mdate.getDate(),0,0,0);
}

function preWorkday(_date) {
  let pdate = new Date(_date);
  pdate.setDate(_date.getDate() - 1);
  while(isHoliday(pdate)){
    pdate.setDate(pdate.getDate() - 1)
  }
  return pdate;
}

function isHoliday (_date) {
  //曜日(0:日曜～6:土曜)を取得し、土日と判定された場合はfalseを返す
  const weekInt = _date.getDay();
  if (weekInt <= 0 || 6 <= weekInt) {
    return true;
  }
  //祝日を判定するため、日本の祝日を公開しているGoogleカレンダーと接続する
  const calendarId = "ja.japanese#holiday@group.v.calendar.google.com";
  const calendar = CalendarApp.getCalendarById(calendarId);
  //イベント(祝日)が設定されているか取得し、イベントが有る場合はfalseを返す
  const event = calendar.getEventsForDay(_date);
  if (event.length > 0) {
    return true;
  }
  return false;
}

function phantomJSCloudScraping(URL) {
  //スクリプトプロパティからPhantomJsCloudのAPIキーを取得する
  let key = PropertiesService.getScriptProperties().getProperty('PHANTOMJSCLOUD_ID');
  //HTTPSレスポンスに設定するペイロードのオプション項目を設定する
  let option =
  {
    url: URL,
    renderType: "HTML",
    outputAsJson: true
  };
  //オプション項目をJSONにしてペイロードとして定義し、エンコードする
  let payload = JSON.stringify(option);
  payload = encodeURIComponent(payload);
  //PhantomJsCloudのAPIリクエストを行うためのURLを設定
  let apiUrl = "https://phantomjscloud.com/api/browser/v2/" + key + "/?request=" + payload;
  //設定したAPIリクエスト用URLにフェッチして、情報を取得する。

  let response = UrlFetchApp.fetch(apiUrl);
  //取得したjsonデータを配列データとして格納
  let json = JSON.parse(response.getContentText());
  //APIから取得したデータからJSから生成されたソースコードを取得
  let source = json["content"]["data"];
  return source;
}
