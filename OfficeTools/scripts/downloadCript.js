// download_script.js

const { chromium } = require("playwright");
const path = require("path");
const fs = require("fs");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");

// --- 1. コマンドライン引数の定義と解析 ---
const argv = yargs(hideBin(process.argv))
  .option("url", {
    alias: "u",
    type: "string",
    description: "自動化を開始するURL",
    demandOption: true, // 必須引数に設定
  })
  .option("dir", {
    alias: "d",
    type: "string",
    description: "ファイルのダウンロード先ディレクトリ",
    demandOption: true,
  })
  .option("keyword", {
    alias: "k",
    type: "string",
    description: "クリプト便アクセス用のパスワード",
    demandOption: true,
  })
  .option("id", {
    type: "string",
    description: "認証用のログインID（任意）",
  })
  .option("pw", {
    type: "string",
    description: "認証用のパスワード（任意）",
  })
  .help()
  .alias("help", "h")
  .epilog("Copyright 2024").argv;

// --- 2. ダウンロードディレクトリの準備 ---
// ディレクトリが存在しない場合は作成 (深い階層もまとめて作成)
if (!fs.existsSync(argv.dir)) {
  console.log(`ディレクトリを作成します: ${argv.dir}`);
  fs.mkdirSync(argv.dir, { recursive: true });
}

async function performAutomation(config) {
  console.log("自動化処理を開始します...");
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(config.url);
  console.log(`ページにアクセスしました: ${config.url}`);

  // --- 3. 認証処理（IDとパスワードが指定されている場合のみ） ---
  // 認証画面が表示され、かつIDとパスワードが両方提供されている場合のみログインを試行
  if (config.id && config.pw) {
    try {
      // 認証画面のID入力フィールドが表示されるのを待つ
      await page.waitForSelector("#i0116", { timeout: 5000 });
      console.log("認証画面を検出しました。ログインを試みます...");
      await page.fill("#i0116", config.id);
      await page.click("#idSIButton9");
      await page.waitForTimeout(2000);
      await page.fill("#i0118", config.pw);
      await page.click("#idSIButton9");
      await page.waitForTimeout(2000); // ログイン後の遷移を待機
      console.log("ログイン処理が完了しました。");
    } catch (error) {
      console.log(
        "認証画面が表示されませんでした。ログイン処理をスキップします。"
      );
    }
  }

  // --- 4. キーワード検索 ---
  console.log(`キーワード「${config.keyword}」で検索します...`);
  await page.waitForSelector(".el-input__inner", { state: "visible" });
  await page.fill(".el-input__inner", config.keyword);

  const openButton = await page.locator('.el-button:has-text("開く")');
  if (await openButton.isVisible()) {
    await openButton.click();
  }

  // --- 5. ファイルダウンロード処理 ---
  await page.waitForSelector(".box-attachment-item", { state: "visible" });
  const fileItems = await page.locator(".box-attachment-item").all();
  console.log(`発見したファイル数: ${fileItems.length}`);

  if (fileItems.length === 0) {
    console.log("ダウンロード対象のファイルが見つかりませんでした。");
    await browser.close();
    return;
  }

  for (const item of fileItems) {
    // ... (forループ内)
    // ページ上の表示テキストはログ出力用に取得するだけに留める（任意）
    const nameElement = item.locator(".name");
    const displayText = (await nameElement.textContent()) || "不明なファイル";

    const downloadButton = item.locator('.el-button:has-text("ダウンロード")');
    console.log(
      `ページ上の表示:「${displayText.trim()}」のダウンロードを開始します...`
    );

    // ダウンロードイベントを待機し、ボタンをクリック
    const [download] = await Promise.all([
      page.waitForEvent("download"),
      downloadButton.click(),
    ]);

    // ★★★ ここが重要 ★★★
    // downloadオブジェクトから推奨ファイル名を取得（拡張子を含む最も確実なファイル名）
    const suggestedFilename = download.suggestedFilename();

    // 取得した推奨ファイル名を使って保存パスを生成する
    const savePath = path.join(config.dir, suggestedFilename);

    // 指定のパスにファイルを保存
    await download.saveAs(savePath);

    console.log(`保存しました: ${savePath}`);
  }

  console.log("すべての処理が完了しました。5秒後にブラウザを閉じます...");
  await page.waitForTimeout(5000);
  await browser.close();
}

// 引数を渡してメインの関数を実行
performAutomation(argv).catch((error) => {
  console.error("処理中にエラーが発生しました:", error);
  process.exit(1); // エラーで終了
});
