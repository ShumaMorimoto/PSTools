const meigaraCount = 15;

//const sheet = SpreadsheetApp.getActiveSheet();
//const mList = sheet.getRange("A2:E" + (meigaraCount + 1));
//const pList = sheet.getRange("D2:G" + (meigaraCount + 1));
//const totalMount = sheet.getRange("I" + (meigaraCount + 3) + ":M" + (meigaraCount + 3));
//const totalMountOld = sheet.getRange("I" + (meigaraCount + 4) + ":M" + (meigaraCount + 4));
//const jikalist = sheet.getRange("B2:L" + (meigaraCount + 1));
//const mDayCell = sheet.getRange(9, meigaraCount + 3)

const priceInfo = LoadTable('基礎情報', 'A1:E14');

function DoOn() {
  Logger.log(result);
}

function OnOpen() {
}

function testDo() {
 const baseDate = new Date('2025/09/12'); // 金曜日
  const result = addWorkday(baseDate, 3);  // 3営業日後 → 2025/09/17（水）
  Logger.log(`結果: ${Utilities.formatDate(result, 'Asia/Tokyo', 'yyyy/MM/dd')}`);
}


function updateJika() {
//  const spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU";
//  const range = "シート1!C1:G18";
//  const jikaRange = "シート1!I17:M19";
//  const bdayRange = "シート1!I17:I18";

  const base = getEffectiveWorkday(); // "M月d日" 形式

  const gs = new OTGSheetDAO(spreadsheetId);
  const tbl  = LoadTable("シート1", "C1:G18");
  const bday =    LoadTable("シート1", "I17:I18");

  if (bday.rows[0].日付 !== base) {
    const jika = LoadTable("シート1", "I17:M19");
    // ローテート
  }
  const codes = tbl.rows.filter(row => row.日付 !== base);

  try {
    const prices = [];

    if (codes.length === 0) {
      log("★★★ SKIPPED（投信更新） ★★★");
    } else {
      log("★★★ START（投信更新） ★★★");

      for (const code of codes) {
        try {
          const start = new Date();
          const price = ToshinDAO.getPrice(code.コード);
          const elapsed = (new Date() - start) / 1000;

          if (price?.date) {
            log(`コード:${price.code} 基準日:${price.date} 基準価額:${price.nav} 前日比:${price.cmp} 処理時間（${elapsed} sec）`);

            code.更新日時 = Utilities.formatDate(new Date(), "Asia/Tokyo", "M月d日 HH:mm");
            code.日付 = formatDate(price.date); // "yyyyMMdd" → "M月d日"
            code.価格 = price.nav;
            code.前日比 = price.cmp;

            tbl.updateRow(code);
            prices.push(price);
          } else {
            log(`【ERROR】コード:${code.コード} 処理時間（${elapsed} sec）`);
          }
        } catch (e) {
          log(`【ERROR】コード:${code.コード} 例外:${e.message}`);
        }
      }
    }

    tbl.load(); // 再読み込み
    const remaining = tbl.rows.filter(row => row.日付 !== base);

    if (remaining.length > 0) {
      log(`★★★ END（投信更新:残${remaining.length}） ★★★`);
      // イベントログ相当（GASではログ出力のみ）
      log(`残銘柄(${remaining.length})`);
    } else {
      sendJika();
      log("★★★ END（メール送信完了） ★★★");
    }
  } catch (e) {
    log("★★★ ERROR ★★★");
    log(e.stack || e.message);
  }
}
