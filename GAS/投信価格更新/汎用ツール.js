/**
 * 営業日の18時以降なら当日、それ以外は前営業日を返す
 * @param {Date} date 判定対象（通常は new Date()）
 * @returns {Date} 判定結果の日付
 */
function getEffectiveWorkday() {
  const calendarId = 'ja.japanese#holiday@group.v.calendar.google.com';
  const calendar = CalendarApp.getCalendarById(calendarId);
  if (!calendar) throw new Error('祝日カレンダーが取得できません');

  const isWorkday = (d) => {
    const day = d.getDay();
    if (day === 0 || day === 6) return false;
    return calendar.getEventsForDay(d).length === 0;
  };

  const getPreviousWorkday = (d) => {
    const prev = new Date(d);
    do {
      prev.setDate(prev.getDate() - 1);
    } while (!isWorkday(prev));
    return prev;
  };

  let current = new Date();
  const hour = current.getHours();

  if (isWorkday(current) && hour >= 18) {
  } else {
    current = getPreviousWorkday(current);
  }
  const month = current.getMonth() + 1; // getMonth() は 0始まり
  const day = current.getDate();
  return `${month}月${day}日`;
}
/**
 * 指定した日付から営業日を加算／減算する
 * @param {Date} date 基準日
 * @param {number} offset 加算する営業日数（負数で減算）
 * @returns {Date} offset営業日後（または前）の日付
 */
function addWorkday(date, offset) {
  const calendarId = 'ja.japanese#holiday@group.v.calendar.google.com';
  const calendar = CalendarApp.getCalendarById(calendarId);
  if (!calendar) throw new Error('祝日カレンダーが取得できません');

  let count = 0;
  let direction = offset >= 0 ? 1 : -1;
  let current = new Date(date);

  while (count < Math.abs(offset)) {
    current.setDate(current.getDate() + direction);
    if (isWorkday(current, calendar)) {
      count++;
    }
  }
  return current;
}
/**
 * 指定した日付が営業日かどうか（土日・祝日を除外）
 * @param {Date} date 判定対象
 * @param {Calendar} calendar 祝日カレンダー
 * @returns {Boolean} true:営業日 / false:休日
 */
function isWorkday(date, calendar) {
  const day = date.getDay(); // 0:日曜, 6:土曜
  if (day === 0 || day === 6) return false;
  const events = calendar.getEventsForDay(date);
  return events.length === 0;
}


function convertXPathToCss(xpath) {
  let css = xpath;
  // 1. 括弧を除去
  while (css.match(/\([^\(\)]+\)/)) {
    css = css.replace(/\(([^\(\)]+)\)/g, '$1');
  }

  // 2. // → 空白
  css = css.replace(/\/\//g, ' ');

  // 3. / → '>'（子要素）
  css = css.replace(/\//g, ' > ');

  // 4. [@class='a b'] → .a.b
  const classRegex = /\[@class='([^']+)'\]/g;
  css = css.replace(classRegex, (_, raw) => {
    return raw.split(/\s+/).map(cls => `.${cls}`).join('');
  });

  // 5. [@id='xxx'] → #xxx
  css = css.replace(/\[@id='([^']+)'\]/g, '#$1');

  // 6. [n] → :eq(n-1)
  css = css.replace(/\[(\d+)\]/g, (_, n) => `:eq(${parseInt(n, 10) - 1})`);

  // 8. 複数スペースを1つに
  css = css.replace(/\s{2,}/g, ' ');

  // 10. *.classname → .classname
  css = css.replace(/\*\.(\w)/g, '.$1');

  return css.trim();
}

//
// Phantom呼び出し
//

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
