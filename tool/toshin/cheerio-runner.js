const cheerio = require("cheerio");

// 引数受け取り（HTMLとセレクター）
const html = process.argv[2];
const selector = process.argv[3];

const $ = cheerio.load(html);

// 最初にマッチした要素の OuterHTML を取得
const element = $(selector).first();
const outerHTML = $.html(element);

console.log(outerHTML);
