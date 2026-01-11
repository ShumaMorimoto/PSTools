// get_elements.js
const { chromium } = require("playwright");

async function fetchElements() {
  const url = process.argv[2];
  let selectorMap;

  try {
    selectorMap = JSON.parse(process.argv[3]);
  } catch (e) {
    console.error("Error: 引数のJSON形式が正しくありません。");
    process.exit(1);
  }

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(15000);

    console.error(`Fetching: ${url}...`);
    await page.goto(url, { waitUntil: "domcontentloaded" });

    const results = {};
    for (const [key, xpath] of Object.entries(selectorMap)) {
      try {
        const loc = page.locator(`xpath=${xpath}`);
        
        // 少なくとも1つの要素が出現するまで待機
        await loc.first().waitFor({ state: "attached" });

        // すべてのノードのテキストを配列で取得
        const texts = await loc.allInnerTexts();
        
        // 前後の空白を削除
        const trimmedTexts = texts.map(t => t.trim());

        // 使い勝手を考え、1件なら文字列、複数なら配列で格納
        results[key] = trimmedTexts.length === 1 ? trimmedTexts[0] : trimmedTexts;

      } catch (e) {
        console.error(`Warning: [${key}] の取得に失敗しました (XPath: ${xpath})`);
        results[key] = null;
      }
    }

    // JSON結果を標準出力へ
    console.log(JSON.stringify(results));
  } catch (e) {
    console.error(`Fatal Error: ${e.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

fetchElements();