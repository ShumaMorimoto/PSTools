const { chromium } = require("playwright");

async function fetchElements() {
  const url = process.argv[2];
  let selectorMap;

  try {
    selectorMap = JSON.parse(process.argv[3]);
  } catch (e) {
    process.exit(1);
  }

  const browser = await chromium.launch({ 
    headless: true,
    args: ["--disable-http2"]
  });

  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(15000);

    console.error(`Fetching: ${url}...`);
    await page.goto(url, { waitUntil: "domcontentloaded" });

    const results = {};
    for (const [key, xpath] of Object.entries(selectorMap)) {
      try {
        // 各要素ごとに「中身が入る（空でもハイフンでもない）」まで個別に待機
        await page.waitForFunction(
          (xp) => {
            const res = document.evaluate(xp, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
            if (!res) return false;
            const text = res.innerText.trim();
            // テキストが存在し、かつ「空」「-」「--」「...」等ではない有効な値を待つ
            return text.length > 0 && !/^[-.・]+$/.test(text);
          },
          xpath,
          { timeout: 8000 } // 各要素の待機上限
        ).catch(() => {
          console.error(`Warning: [${key}] wait timeout or empty`);
        });

        const loc = page.locator(`xpath=${xpath}`);
        const texts = await loc.allInnerTexts();
        const trimmed = texts.map(t => t.trim());
        
        results[key] = trimmed.length === 1 ? trimmed[0] : (trimmed.length === 0 ? null : trimmed);
      } catch (e) {
        results[key] = null;
      }
    }

    console.log(JSON.stringify(results));
  } catch (e) {
    console.error(`Fatal Error: ${e.message}`);
  } finally {
    await browser.close();
  }
}

fetchElements();