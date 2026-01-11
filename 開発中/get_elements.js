const { chromium } = require("playwright");

async function fetchElements() {
  const url = process.argv[2];
  let selectorMap;

  try {
    selectorMap = JSON.parse(process.argv[3]);
  } catch (e) {
    process.exit(1);
  }

  // HTTP/2無効化などの引数を追加
  const browser = await chromium.launch({
    headless: false,
    args: ["--disable-http2"],
  });

  try {
    // ユーザーエージェントを偽装
    // ユーザーエージェントに加えて、言語設定などを追加して人間味を出す
    const context = await browser.newContext({
      userAgent:
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      viewport: { width: 1280, height: 800 },
      locale: "ja-JP",
    });
    const page = await context.newPage();

    // ページ全体のタイムアウトを伸ばす
    page.setDefaultTimeout(30000);

    try {
      // waitUntil: "commit" にすることで、接続が確立した瞬間に次へ進む
      await page.goto(url, { waitUntil: "commit" });
    } catch (e) {
      console.log(
        JSON.stringify({ _error: `Navigation failed: ${e.message}` })
      );
      return;
    }

    const results = {};
    for (const [key, xpath] of Object.entries(selectorMap)) {
      try {
        const loc = page.locator(`xpath=${xpath}`).first();
        // ★ ページ遷移完了ではなく、ここで「特定の要素」が出るのを個別に待つ
        // state: "attached" (DOMに存在すればOK) または "visible"
        await loc.waitFor({ state: "attached", timeout: 15000 });
        results[key] = (await loc.innerText()).trim();
      } catch (e) {
        results[key] = null;
      }
    }
    console.log(JSON.stringify(results));
  } catch (e) {
    console.error(e);
  } finally {
    await browser.close();
  }
}

fetchElements();
