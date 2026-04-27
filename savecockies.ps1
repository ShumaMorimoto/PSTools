# 1. DLLの読み込み（パスは実際の環境に合わせて変更してください）
$dllPath = "C:\path\to\Microsoft.Playwright.dll"
Add-Type -Path $dllPath

# 2. Playwrightの初期化（非同期のため .GetAwaiter().GetResult() を使用）
$playwright = [Microsoft.Playwright.Playwright]::CreateAsync().GetAwaiter().GetResult()

# 3. ブラウザ起動オプションの設定
$launchOptions = New-Object Microsoft.Playwright.BrowserTypeLaunchOptions
$launchOptions.Headless = $false

# 4. ブラウザ、コンテキスト、ページの作成
$browser = $playwright.Chromium.LaunchAsync($launchOptions).GetAwaiter().GetResult()
$context = $browser.NewContextAsync().GetAwaiter().GetResult()
$page = $context.NewPageAsync().GetAwaiter().GetResult()

# 5. アクセス
$page.GotoAsync("https://www.fidelity.co.jp/").GetAwaiter().GetResult()

# 6. PowerShellコンソールで入力待ち
Read-Host "ブラウザで手動操作が終わったら、この画面でEnterキーを押してください"

# 7. 状態の保存（オプションオブジェクトを作って渡す）
$storageOptions = New-Object Microsoft.Playwright.BrowserContextStorageStateOptions
$storageOptions.Path = "state.json"

$context.StorageStateAsync($storageOptions).GetAwaiter().GetResult()
Write-Host "状態を state.json に保存しました！" -ForegroundColor Green

# 8. 終了処理
$browser.CloseAsync().GetAwaiter().GetResult()
