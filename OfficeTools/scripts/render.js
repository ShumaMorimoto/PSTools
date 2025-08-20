const { chromium } = require("playwright");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");

// --- 引数のパース ---
const argv = yargs(hideBin(process.argv))
  .usage("使用法: node get_html.js <URL> [--wait <ms>]")
  .option("wait", {
    alias: "w",
    type: "number",
    description: "ページ読み込み後の待機時間（ミリ秒）",
    default: 1000,
  })
  .demandCommand(1, "URLを指定してください")
  .help().argv;

const targetUrl = argv._[0];
const waitMs = argv.wait;

/**
 * HTMLを取得するメイン関数
 * @param {string} url 対象URL
 * @param {number} waitMs 待機時間（ミリ秒）
 */
async function fetchHtml(url, waitMs) {
  let browser;
  try {
    browser = await chromium.launch();
    const page = await browser.newPage();

    console.error(`アクセス中: ${url}`);
    await page.goto(url, { waitUntil: "domcontentloaded" });

    console.error(`待機中: ${waitMs}ms`);
    await page.waitForTimeout(waitMs);

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
fetchHtml(targetUrl, waitMs);
