function GetPrice(code) {
  const MUFJ_CODES = ['2004022702', '2017022703', '201707310A', '2016012906'];

  if (MUFJ_CODES.includes(code)) {
    return getPriceFromMUFJ(code);
  }
  const config = priceInfo.rows.find(item => item.code === code);

  config.bpath = convertXPathToCss(config.bpath)
  config.npath = convertXPathToCss(config.npath)
  config.cpath = convertXPathToCss(config.cpath)

  let content = phantomJSCloudScraping(config.url);
  let price = getParsedPrice(content, config);

  if (!price.date) {
    return getPriceFromWLTA(code);
  }
  return price;
}
function getPriceFromMUFJ(code) {
  const codeTable = {
    '2004022702': '148106',
    '2017022703': '252653',
    '201707310A': '252845',
    '2016012906': '261385'
  };

  const fundCode = codeTable[code];
  if (!fundCode) {
    throw new Error(`Unknown MUFJ code: ${code}`);
  }

  const url = `https://developer.am.mufg.jp/fund_information_latest/fund_cd/${fundCode}`;
  const response = UrlFetchApp.fetch(url, {
    method: 'get',
    contentType: 'application/json; charset=utf-8',
    muteHttpExceptions: true
  });
  const json = JSON.parse(response.getContentText());
  const dataset = json.datasets?.[0];
  if (!dataset) {
    throw new Error(`No dataset found for code: ${code}`);
  }
  return {
    code: code,
    date: dataset.base_date,
    nav: dataset.nav,
    cmp: dataset.cmp_prev_day
  };
}
function getPriceFromWLTA(code) {
  const config = priceInfo.rows.find(item => item.code === 'default');
  const url = config.url + code;

  config.bpath = convertXPathToCss(config.bpath)
  config.npath = convertXPathToCss(config.npath)
  config.cpath = convertXPathToCss(config.cpath)

  let content = phantomJSCloudScraping(config.url);
  let price = getParsedPrice(content, config);
  price.code = code;

  return price;
}
function getPriceFromNikkei(code) {
  while (code.length < 8) {
    code = "0" + code;
  }
  const config = priceInfo.rows.find(item => item.code === 'nikkei');
  const url = config.url + code;

  config.bpath = convertXPathToCss(config.bpath)
  config.npath = convertXPathToCss(config.npath)
  config.cpath = convertXPathToCss(config.cpath)

  let content = phantomJSCloudScraping(config.url);
  let price = getParsedPrice(content, config);
  price.code = code;
  return price;
}
function getParsedPrice(htmlText, config) {
  const $ = Cheerio.load(htmlText);

  // 📅 日付処理
  let base = $(config.bpath).text().replace(/年|月/g, "/");
  const dateMatch = base.match(/[\d/]+/);
  if (dateMatch) {
    const parts = dateMatch[0].split("/");
    const yyyy = parts[0].padStart(4, "0");
    const mm = parts[1].padStart(2, "0");
    const dd = parts[2] ? parts[2].padStart(2, "0") : "01";
    base = `${yyyy}${mm}${dd}`;
  }

  // 💰 NAV処理
  let nav = $(config.npath).text();
  const navMatch = nav.match(/[\d,]+/);
  if (navMatch) {
    nav = navMatch[0];
  }

  // 📉 比較値処理
  let cmp = $(config.cpath).text();
  const cmpMatch = cmp.match(/[-\d,]+/);
  if (cmpMatch) {
    cmp = cmpMatch[0];
  }

  // 🧾 結果オブジェクト
  return {
    code: config.code,
    date: base,
    nav: nav,
    cmp: cmp
  };
}

