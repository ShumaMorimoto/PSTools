const cheerio = require('cheerio');

// 引数からCSSセレクターを取得
const selector = process.argv[2];
if (!selector) {
  console.error("❌ セレクターが指定されていません");
  process.exit(1);
}

// 標準入力からHTMLを読み込む
let html = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => html += chunk);
process.stdin.on('end', () => {
  const $ = cheerio.load(html);

  // セレクターで要素を抽出
  const element = $(selector).first();

  // OuterHTMLを出力
  console.log($.html(element));
});