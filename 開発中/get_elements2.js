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

  const browser = await chromium.launch({ headless: false });
  try {
    const page = await browser.newPage();
    // タイムアウト設定
    page.setDefaultTimeout(15000);

    // 進捗ログを標準エラー出力(stderr)に出すと、PowerShellの結果取得を邪魔しません
    console.error(`Fetching: ${url}...`);
    await page.goto(url, { waitUntil: "domcontentloaded" });

    const results = {};
    for (const [key, xpath] of Object.entries(selectorMap)) {
      try {
        const loc = page.locator(`xpath=${xpath}`).first();
        // 要素の出現を待機
        await loc.waitFor({ state: "attached" }); 
        results[key] = (await loc.innerText()).trim();
      } catch (e) {
        console.error(`Warning: [${key}] の取得に失敗しました (XPath: ${xpath})`);
        results[key] = null;
      }
    }

    // 最終的なJSON結果だけを標準出力(stdout)に送る
    console.log(JSON.stringify(results));
  } catch (e) {
    console.error(`Fatal Error: ${e.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

fetchElements();