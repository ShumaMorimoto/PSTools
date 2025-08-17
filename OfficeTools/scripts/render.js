// get_html.js

const { chromium } = require("playwright");

/**
 * メインの処理を実行する非同期関数
 * @param {string} targetUrl 取得対象のURL
 */
async function fetchHtml(targetUrl) {
  let browser;
  try {
    // ヘッドレスモードでブラウザを起動
    browser = await chromium.launch();
    const page = await browser.newPage();

    // 処理ログは標準エラー出力へ
    console.error(`ページにアクセスしています: ${targetUrl}`);

    // 指定されたURLに移動し、ページの読み込みが完了するのを待つ
    await page.goto(targetUrl, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(3000);

    // ページの完全なHTMLコンテンツを取得
    const html = await page.content();

    // 取得したHTMLを標準出力へ出力
    console.log(html);
  } catch (error) {
    // エラーメッセージは標準エラー出力へ
    console.error(`エラーが発生しました: ${error.message}`);
    process.exit(1); // エラーで終了
  } finally {
    // 処理が成功しても失敗しても、必ずブラウザを閉じる
    if (browser) {
      await browser.close();
    }
  }
}

// --- スクリプトのエントリーポイント ---

// コマンドラインからURL引数を取得
const url = process.argv[2];

// URLが指定されていない場合は、使い方を表示して終了
if (!url) {
  console.error("エラー: URLを引数として指定してください。");
  console.error("使用法: node get_html.js <URL>");
  process.exit(1);
}

// メイン関数を実行
fetchHtml(url);
