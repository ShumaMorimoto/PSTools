const puppeteer = require('puppeteer');

// PowerShellから渡されたURLを取得
const url = process.argv[2];

if (!url) {
    console.error('URLが指定されていません。');
    process.exit(1);
}

(async () => {
    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: 'networkidle2' });

    const html = await page.evaluate(() => {
        return document.documentElement.outerHTML;
    });
    console.log(html);

    await browser.close();
})();