const { chromium } = require("playwright");

async function fetchElements() {
  const url = process.argv[2];
  let selectorMap;

  try {
    selectorMap = JSON.parse(process.argv[3]);
  } catch (e) {
    process.exit(1);
  }

  // HTTP/2エラーだけは防ぐために引数を追加
  const browser = await chromium.launch({ 
    headless: true,
    args: ["--disable-http2"]
  });

  try {
    const page = await browser.newPage();
    // 個別要素の待機は10秒、全体の遷移は15秒程度に設定
    page.setDefaultTimeout(15000);

    console.error(`Fetching: ${url}...`);

    // ★ waitUntil を domcontentloaded に戻してタイムアウトを回避
    await page.goto(url, { waitUntil: "domcontentloaded" });

    const results = {};
    for (const [key, xpath] of Object.entries(selectorMap)) {
      try {
        const loc = page.locator(`xpath=${xpath}`).first();
        
        // ★ ここが肝：JSで値が「表示」されるまで待つ
        // attachedよりも厳格に「中身がある状態」を待てます
        await loc.waitFor({ state: "visible", timeout: 10000 });

        const texts = await page.locator(`xpath=${xpath}`).allInnerTexts();
        const trimmed = texts.map(t => t.trim());
        results[key] = trimmed.length === 1 ? trimmed[0] : (trimmed.length === 0 ? null : trimmed);

      } catch (e) {
        // 取得失敗時は null を入れる（Fatalにならないようにする）
        results[key] = null;
      }
    }

    console.log(JSON.stringify(results));
  } catch (e) {
    // ページ遷移自体のエラー時
    console.log(JSON.stringify({ _error: e.message }));
  } finally {
    await browser.close();
  }
}

fetchElements();