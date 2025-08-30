const meigaraCount = 15;

const sheet = SpreadsheetApp.getActiveSheet();
const mList = sheet.getRange("A2:E" + (meigaraCount + 1));
const pList = sheet.getRange("D2:G" + (meigaraCount + 1));
const totalMount = sheet.getRange("I" + (meigaraCount + 3) + ":M" + (meigaraCount + 3));
const totalMountOld = sheet.getRange("I" + (meigaraCount + 4) + ":M" + (meigaraCount + 4));
const jikalist = sheet.getRange("B2:L" + (meigaraCount + 1));
const mDayCell = sheet.getRange(9, meigaraCount + 3)

function DoOn() {
  if (!isHoliday(new Date())) {
    updateJika();
    sendJika();
  }
}

function OnOpen() {
  updateJika();
}

function testDo() {

  //  getPriceSMD("");
  //  getPriceWTADV("2012052801")
  //  getPriceASAHI()
  //  getPriceFDLTY('217004')
  //  getPriceSMD()
  //  getPriceIFREE()
  //  getPricePICTET()
  //  getPriceNAM("dcngkif")

  //  getPriceNOMURA("400029")
  //  getPriceNIKKO()
  //   getPrice123P()


  getPrice("2004022702")


  //   let driver = new WebDriver("https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html")
  //    let str = driver.findElementByClassName("text-[19px] md:text-[28px]")
  //    console.log(str)

  //    updateJika();
  //    sendJika();

  // console.log(SetJika(250874,"20240603",10000,-100));

}
function doGet(e) {

  const output = ContentService.createTextOutput();
  output.setMimeType(ContentService.MimeType.JSON);

  var code = e.parameter.code;
  var date = e.parameter.date;
  var nav = e.parameter.nav;
  var cmp = e.parameter.cmp;

  console.log("code:" + code);
  console.log("date:" + date);
  console.log("nav:" + nav);
  console.log("cmp:" + cmp);


  if (code == null || date == null || nav == null || cmp == null) {

    output.setContent(JSON.stringify({ Status: "OK", data: GetJika() }));


  } else {
    //    code = getWTADVCode(code);
    output.setContent(JSON.stringify({ Status: SetJika(code, date, nav, cmp), 投信コード: code, 基準日: date, 基準価額: nav, 前日比: cmp }));
  }

  return output
}

function unupdatecodes() {
  const mday = mDay();  // 現在

  let MEIGARA = mList.getValues();

  let array = []
  MEIGARA.forEach(function (meigara) {
    let code = meigara[2];
    let kijyunbi = meigara[4];
    if (kijyunbi < mday) {
      array = array.concat([{ "code": code, "update": Utilities.formatDate(kijyunbi, "JST", "yyyyMMdd") }])
    }
  })
  return JSON.stringify(array)
}


function SetJika(code, _date, nav, cmp) {
  const mday = mDay();  // 現在
  const date = new Date(_date.slice(0, 4), _date.slice(4, 6) - 1, _date.slice(6, 8), 0, 0, 0);

  const searchRange = sheet.getRange("C2:C");
  const textObject = searchRange.createTextFinder(code);
  const results = textObject.findAll();

  if (results.length == 0) {
    return "NOCODE";
  } else {
    results.forEach(function (cell) {
      var row = cell.getRow(); // 該当セルの行番号を取得
      var eCell = sheet.getRange(row, 5).getValue(); // B列のセルの値を取得

      if (eCell < date) { // B列が空白の場合のみ処理を実行
        var targetRange = sheet.getRange(row, 4, 1, 4); // B列～D列の範囲を取得
        targetRange.setValues([[_now, date, nav, cmp]]); // B列～D列に "0" を設定
        targetRange.setFontColor("green"); // 文字の色を緑に変更
        return 'UPDATED';
      }
    });
    return 'SKIPPED';
  }
}

function updateJika() {
  const mday = mDay();  // 取得できる基準日
  const pday = totalMountOld.getValues()[0][0];
  var zan = !(pday >= mday);   // true:残あり　false:残なし

  lotateMount()

  if (zan) {
    let MEIGARA = mList.getValues();
    let PRICES = pList.getValues();
    zan = false;

    for (i = 0; i < MEIGARA.length; i++) {
      let ryaku = MEIGARA[i][1];
      let code = MEIGARA[i][2];
      let kijyunbi = MEIGARA[i][4];

      try {
        if (kijyunbi < mday) {
          let price = getPrice(code);
          PRICES[i][0] = new Date();
          PRICES[i][1] = price[0];
          PRICES[i][2] = price[1];
          PRICES[i][3] = price[2];

          if (PRICES[i][1] < mday) {
            zan = true;
          }
        }
        console.log(
          Utilities.formatDate(PRICES[i][0], 'JST', 'MM/dd HH:mm') + " " +
          ryaku + " : " +
          Utilities.formatDate(PRICES[i][1], 'JST', 'MM/dd') + ": " +
          PRICES[i][2].toLocaleString() + " (" +
          PRICES[i][3].toLocaleString() + ")"
        );
      }
      catch {
        console.log(
          MEIGARA[i][0] + ": Error"
        )
      }
    }
    pList.setValues(PRICES);

    for (var i = 0; i < PRICES.length; i++) {
      var targetRange = sheet.getRange(pList.getRow() + i, pList.getColumn() + 1, 1, 7); // E列～L列（5列目～12列目）
      if (PRICES[i][1] >= mday) {
        targetRange.setFontColor("green"); // 正の値なら緑
      } else {
        targetRange.setFontColor("black"); // それ以外は黒
      }
    }
  }
}

function lotateMount() {
  let TTM = totalMount.getValues();
  let mday = mDay();

  if (TTM[0][0] < mday) {
    sheet.insertRowsAfter(meigaraCount + 3, 1);
    totalMountOld.setValues(TTM);
    sheet.getRange(totalMount.getRow(), totalMount.getColumn()).setValue(mday)
  }
}


function GetJika() {
  let JIKAS = jikalist.getValues();
  let TTM = totalMount.getValues();
  let MEIGARA = mList.getValues();

  const mday = mDay();  // 現在

  let array = []
  MEIGARA.forEach(function (meigara) {
    let code = meigara[2];
    let kijyunbi = meigara[4];
    if (kijyunbi < mday) {
      array = array.concat([{ "code": code, "update": Utilities.formatDate(kijyunbi, "JST", "yyyyMMdd") }])
    }
  })

  var obj = {
    codes: array,
    jika: Math.round(TTM[0][1]),
    soneki: Math.round(TTM[0][2]),
    cmp: Math.round(TTM[0][3]),
    data: []
  }

  for (let jika of JIKAS) {
    obj.data.push([
      {
        name: jika[0],
        date: Utilities.formatDate(jika[3], "JST", "MM/dd"),
        nav: jika[4],
        cmp: jika[5],
        soneki: Math.round(jika[10])
      }
    ])
  }
  console.log(JSON.stringify(obj));
  return obj
}

function sendJika() {
  let JIKAS = jikalist.getValues();
  let TTM = totalMount.getValues();

  let body =
    "時価：" + Math.round(TTM[0][1]).toLocaleString() + "円" +
    "損益：" + Math.round(TTM[0][2]).toLocaleString() + "円  (前日比 " +
    Math.round(TTM[0][3]).toLocaleString() + "円 )\n\n";

  for (let jika of JIKAS) {
    body +=
      (jika[0] + "　　　　").slice(0, 7) +
      Utilities.formatDate(jika[3], "JST", "MM/dd") + "  " +
      ("   " + jika[4].toLocaleString()).slice(-6) + " (" +
      ("   " + jika[5].toLocaleString()).slice(-5) + ")  :" +
      signedNum(Math.round(jika[10]), 10) + "\n"
  }
  console.log(body);
  GmailApp.sendEmail("shumamorimoto@gmail.com", "【投信:" + Math.round(TTM[0][3]).toLocaleString() + "円@" + Utilities.formatDate(new Date(), 'JST', 'HH:mm）】'), body);
}


let pricesrc = {
  2000032406: {
    url: 'https://www.alamco.co.jp/fund/globalvalue/index.html',
    bkey: ".date", bidx: 0,
    nkey: ".def-price", nidx: 0,
    ckey: ".comp-price", cidx: 0
  },
  1998040104: {
    url: 'https://www.fidelity.co.jp/funds/detail/217004/F',
    bkey: ".factsheet-asOfDate", bidx: 0,
    nkey: ".medium-shrink", nidx: 0,
    ckey: ".medium-auto", cidx: 0
  },
  2001112212: {
    url: 'https://www.fidelity.co.jp/funds/detail/216201/F',
    bkey: ".factsheet-asOfDate", bidx: 0,
    nkey: ".medium-shrink", nidx: 0,
    ckey: ".medium-auto", cidx: 0
  },
  2011083106: {
    url: 'https://www.smd-am.co.jp/fund/153406/',
    bkey: ".sw-Text-right", bidx: 0,
    nkey: "td", nidx: 0,
    ckey: "td", cidx: 1
  },
  2023031301: {
    url: 'https://www.daiwa-am.co.jp/funds/detail/3484/detail_top.html',
    bkey: ".date", bidx: 0,
    nkey: "td", nidx: 0,
    ckey: "td", cidx: 1
  },
  2005022803: {
    url: 'https://www.pictet.co.jp/fund/gloin.html',
    bkey: ".cmp-fund__fund-summary-value", bidx: 0,
    nkey: ".cmp-fund__fund-summary-value", nidx: 1,
    ckey: ".cmp-fund__fund-summary-value", cidx: 2
  },
  2013121001: {
    url: 'https://www.nam.co.jp/fundinfo/dcngkif/main.html',
    bkey: ".p-fundinfoFundValue__date", bidx: 0,
    nkey: ".fundValue__item", nidx: 0,
    ckey: ".fundValue__item", cidx: 1
  },
  2011110102: {
    url: 'https://www.nam.co.jp/fundinfo/ngkkp/main.html',
    bkey: ".p-fundinfoFundValue__date", bidx: 0,
    nkey: ".fundValue__item", nidx: 0,
    ckey: ".fundValue__item", cidx: 1
  },
  2004073003: {
    url: 'https://www.nomura-am.co.jp/fund/funddetail.php?fundcd=400029',
    bkey: "td", bidx: 0,
    nkey: "td", nidx: 1,
    ckey: "td", cidx: 2
  },
  '201707310D': {
    url: 'https://www.nikkoam.com/fund/detail/643718',
    bkey: ".p-products-price__label", bidx: 0,
    nkey: ".p-products-price__number", nidx: 0,
    ckey: ".p-products-price__number", cidx: 1
  },
  2012052801: {
    url: 'https://hifumi.rheos.jp/fund/plus/',
    bkey: ".hf-js-date", bidx: 0,
    nkey: "td", nidx: 0,
    ckey: "td", cidx: 1
  },
  default: {
    url: 'https://www.wealthadvisor.co.jp/snapshot/',
    bkey: ".common-normal-1", bidx: 1,
    nkey: ".common-normal-l", nidx: 0,
    ckey: ".head-table-clm-data", cidx: 3
  }
}

function getPrice(code) {
  let price = [], url

  if (code in pricesrc) {
    url = pricesrc[code].url
  } else {
    url = pricesrc["default"].url + code
    code = "default"
  }

  let content = phantomJSCloudScraping(url);
  let $ = Cheerio.load(content); //コンテントの読み込み

  price.push(new Date($(pricesrc[code].bkey).eq(pricesrc[code].bidx).text().replace(/[年月]/g, "/").match(/[\d/]+/)));
  price.push($(pricesrc[code].nkey).eq(pricesrc[code].nidx).text().match(/[\d\,]+/)[0]);
  price.push($(pricesrc[code].ckey).eq(pricesrc[code].cidx).text().match(/[\d\,-]+/)[0]);

  return price
}

function getWTADVCode(code) {
  switch (code) {

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

function signedNum(_num, keta) {
  var sign = _num >= 0 ? '+' : ''; // 正の数には "+" を付ける
  return (sign + _num).padStart(keta, ' ');
}

function mDay() {
  let mdate = new Date();
  mdate.setHours(mdate.getHours() + 6);
  mdate = preWorkday(mdate);
  return new Date(mdate.getFullYear(), mdate.getMonth(), mdate.getDate(), 0, 0, 0);
}

function preWorkday(_date) {
  var previousDay = new Date(_date);
  do {
    previousDay.setDate(previousDay.getDate() - 1); // 1日前に移動
  } while (isHoliday(previousDay));
  return previousDay
}

function isHoliday(_date) {
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
