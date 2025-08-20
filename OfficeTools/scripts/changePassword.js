const { chromium } = require("playwright");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");

/**
 * NRIのパスワード変更ページでパスワードを自動変更する関数
 * @param {string} userId - 社内システム共通ID
 * @param {string} currentPassword - 現在のパスワード
 * @param {string} newPassword - 新しいパスワード
 * @param {object} options - 実行オプション。{ headless: boolean } を指定可能。
 * @returns {Promise<{success: boolean, message: string}>}
 *          成功時は { success: true, message: '成功メッセージ' }
 *          失敗時は { success: false, message: 'エラーメッセージ' }
 */
async function changePassword(
  userId,
  currentPassword,
  newPassword,
  options = {}
) {
  const { headless = true } = options;

  let browser;
  try {
    console.log("ブラウザを起動しています...");
    browser = await chromium.launch({ headless });
    const context = await browser.newContext();
    const page = await context.newPage();

    const targetUrl = "http://comainu.cu.nri.co.jp/passwd_change/";

    await page.goto(targetUrl);
    console.log(`-> ${targetUrl} にアクセスしました。`);

    page.on("dialog", async (dialog) => {
      console.log(
        `-> ダイアログメッセージ: 「${dialog.message().replace(/\n/g, " ")}」`
      );
      await dialog.accept();
      console.log("-> 確認ダイアログを承認しました。");
    });

    console.log("フォームに入力しています...");
    await page.locator('input[name="AuthenticationID"]').fill(userId);
    await page.locator('input[name="OldPassword"]').fill(currentPassword);
    await page.locator('input[name="NewPassword"]').fill(newPassword);
    await page.locator('input[name="NewPasswordConfirm"]').fill(newPassword);
    console.log("-> 入力が完了しました。");

    console.log("「パスワード変更」ボタンをクリックします...");
    await page
      .getByRole("button", { name: "パスワード変更(Change password)" })
      .click();

    console.log(
      "-> ボタンをクリックしました。結果ページの読み込みを待ちます。"
    );

    const timeout = 30000; // タイムアウト設定 (30秒)

    // 成功メッセージが表示されるのを待つPromise
    const successPromise = page
      .locator('#ResultMessage:has-text("パスワードを変更しました。")')
      .waitFor({ state: "visible", timeout });

    // エラーメッセージが表示されるのを待つPromise
    const errorPromise = page
      .locator("#ErrorMessage b")
      .waitFor({ state: "visible", timeout });

    // Promise.race を使って、成功と失敗のどちらが先に発生するかを待つ
    const result = await Promise.race([
      successPromise.then(() => "success"),
      errorPromise.then(() => "error"),
    ]);

    if (result === "success") {
      const messageText = await page.locator("#ResultMessage").textContent();
      const successMessage = `成功メッセージを確認しました: "${messageText
        .trim()
        .replace(/\s+/g, " ")}"`;
      console.log(`-> ${successMessage}`);
      return { success: true, message: successMessage };
    } else if (result === "error") {
      // エラーの場合、エラーメッセージを取得して例外をスローする
      const errorMessageText = await page
        .locator("#ErrorMessage")
        .textContent();
      const failureMessage = `パスワード変更に失敗しました。ページのエラー内容: ${errorMessageText
        .trim()
        .replace(/\s+/g, " ")}`;
      throw new Error(failureMessage);
    } else {
      // このブロックには通常到達しない
      throw new Error("予期せぬ状態でタイムアウトしました。");
    }
  } catch (error) {
    // catchブロックでエラー詳細を含むオブジェクトを返す
    return { success: false, message: error.message };
  } finally {
    if (browser) {
      await browser.close();
      console.log("ブラウザを閉じました。");
    }
  }
}

// --- このスクリプトを直接実行した場合の処理 ---
if (require.main === module) {
  const argv = yargs(hideBin(process.argv))
    .option("id", {
      alias: "i",
      description: "社内システム共通ID",
      type: "string",
      demandOption: true,
    })
    .option("pw", {
      alias: "p",
      description: "現在のパスワード",
      type: "string",
      demandOption: true,
    })
    .option("new", {
      alias: "n",
      description: "新しいパスワード",
      type: "string",
      demandOption: true,
    })
    .option("headless", {
      description: "ブラウザを表示せずに実行 (デバッグ時は --no-headless)",
      type: "boolean",
      default: true,
    })
    .help()
    .alias("help", "h").argv;

  (async () => {
    const runOptions = {
      headless: argv.headless,
    };

    // 通常のログは標準出力へ
    console.log(`--- パスワード変更を開始します ---`);
    console.log(`対象ID: ${argv.id}`);
    console.log(`ヘッドレスモード: ${runOptions.headless}`);

    const result = await changePassword(argv.id, argv.pw, argv.new, runOptions);

    if (result.success) {
      console.log("\n✅ スクリプトは正常に終了しました。");
      process.exit(0); // 成功を示す終了コード 0 でプロセスを終了
    } else {
      // エラーメッセージを標準エラー出力(stderr)へ出力
      console.error(result.message);
      process.exit(1); // 失敗を示す終了コード 1 でプロセスを終了
    }
  })();
}

module.exports = { changePassword };
