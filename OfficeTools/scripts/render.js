const { chromium } = require("playwright");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");

// --- 引数のパース ---
const argv = yargs(hideBin(process.argv))
  .usage("使用法: node get_html.js <URL> [--wait <ms>] [--xpath <XPath>]")
  .option("wait", {
    alias: "w",
    type: "number",
    description: "ページ読み込み後の待機時間（ミリ秒）",
    default: 1000,
  })
  .option("xpath", {
    alias: "x",
    type: "string",
    description: "指定したXPathの要素のテキストが設定されるまで待機",
  })
  .demandCommand(1, "URLを指定してください")
  .help().argv;

const targetUrl = argv._[0];
const waitMs = argv.wait;
const xpath = argv.xpath;

/**
 * HTMLを取得するメイン関数
 * @param {string} url 対象URL
 * @param {number} waitMs 待機時間（ミリ秒）
 * @param {string} xpath XPathセレクタ
 */
async function fetchHtml(url, waitMs, xpath) {
  let browser;
  try {
    browser = await chromium.launch();
    const page = await browser.newPage();

    console.error(`アクセス中: ${url}`);
    await page.goto(url, { waitUntil: "domcontentloaded" });

    if (xpath) {
      console.error(`XPathテキスト待機開始: ${xpath}`);
      const start = Date.now();

      await page.waitForFunction(
        (xp) => {
          const result = document.evaluate(
            xp,
            document,
            null,
            XPathResult.FIRST_ORDERED_NODE_TYPE,
            null
          ).singleNodeValue;
          return result && result.innerText.trim().length > 0;
        },
        xpath,
        { timeout: 10000 }
      );

      const elapsed = Date.now() - start;
//      const elementHandle = await page.$(`xpath=${xpath}`);
//      const text = await elementHandle.evaluate((el) => el.innerText.trim());
      console.error(
        `XPath要素のテキストが設定されました（待機時間: ${elapsed}ms）`
      );

    } else {
      console.error(`待機中: ${waitMs}ms`);
      await page.waitForTimeout(waitMs);
    }

    const html = await page.content();
    console.log(html);
  } catch (error) {
    console.error(`エラー: ${error.message}`);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

// 実行
fetchHtml(targetUrl, waitMs, xpath);