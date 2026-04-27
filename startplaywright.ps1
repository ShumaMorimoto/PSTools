$dllPath = "C:\path\to\Microsoft.Playwright.dll"
Add-Type -Path $dllPath

$playwright = [Microsoft.Playwright.Playwright]::CreateAsync().GetAwaiter().GetResult()

$launchOptions = New-Object Microsoft.Playwright.BrowserTypeLaunchOptions
$launchOptions.Headless = $false
$browser = $playwright.Chromium.LaunchAsync($launchOptions).GetAwaiter().GetResult()

# ここで保存したJSONを指定してコンテキストを作成
$contextOptions = New-Object Microsoft.Playwright.BrowserNewContextOptions
$contextOptions.StorageStatePath = "state.json"

$context = $browser.NewContextAsync($contextOptions).GetAwaiter().GetResult()
$page = $context.NewPageAsync().GetAwaiter().GetResult()

$page.GotoAsync("https://www.fidelity.co.jp/").GetAwaiter().GetResult()
Write-Host "保存された状態を使ってアクセスしました。" -ForegroundColor Cyan

# 確認のために少し待つ
Start-Sleep -Seconds 5
$browser.CloseAsync().GetAwaiter().GetResult()
