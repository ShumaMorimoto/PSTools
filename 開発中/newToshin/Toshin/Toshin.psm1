# ─── モジュール初期化 ───
$script:ModuleRoot = $PSScriptRoot

# 1. DLLのロード
$dllPath = Join-Path $script:ModuleRoot "lib\GenericScraper.dll"
if (Test-Path $dllPath) {
    try {
        [Reflection.Assembly]::LoadFrom($dllPath) > $null
    }
    catch {
        Write-Error "DLLのロードに失敗しました: $($_.Exception.Message)"
    }
}

# ─── クラス定義 ───
class ToshinDAO : IDisposable {
    hidden [object]$scraper
    hidden static [hashtable]$pricesrc = @{}

    # コンストラクタ
# --- コンストラクタ ---

    # デフォルトコンストラクタ（デフォルトはHeadless = true）
    ToshinDAO() {
        $this.Init($true)
    }

    # モードを指定できるコンストラクタ
    ToshinDAO([bool]$isHeadless) {
        $this.Init($isHeadless)
    }

    # 共通の初期化ロジック
    hidden [void] Init([bool]$isHeadless) {
        # 1. configから価格定義をロード
        if ([ToshinDAO]::pricesrc.Count -eq 0) {
            $configFile = Join-Path $PSScriptRoot "config\PriceSources.json"
            if (Test-Path $configFile) {
                $json = Get-Content $configFile -Raw | ConvertFrom-Json
                foreach ($prop in $json.psobject.Properties) {
                    [ToshinDAO]::pricesrc[$prop.Name] = $prop.Value
                }
            }
        }

        # 2. DLL内のコアクラスを探索
        $typeName = "GenericScraper.WebScraperCore"
        $type = [AppDomain]::CurrentDomain.GetAssemblies() | 
        ForEach-Object { $_.GetType($typeName) } | 
        Where-Object { $null -ne $_ } | Select-Object -First 1

        if ($null -eq $type) {
            throw "型 [$typeName] が見つかりません。DLLを確認してください。"
        }

        # 3. インスタンス生成とブラウザ初期化 (引数の $isHeadless を使用)
        $this.scraper = [Activator]::CreateInstance($type)
        $this.scraper.InitializeAsync($isHeadless).GetAwaiter().GetResult()
    }
    
    # --- 価格取得メソッド群 ---

    # 通常取得（個別サイト失敗時にWLTへ切り替え）
    [PSCustomObject] GetPrice([string]$code) {
        # 1. MUFJ API 特例
        if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906')) {
            return [ToshinDAO]::getPriceMUFJ($code)
        }

        # 2. 個別サイトでの取得試行
        $config = [ToshinDAO]::pricesrc[$code]
        if ($null -ne $config) {
            $price = $this.InternalScrape($code, $config.url, $config, 0)
            
            # 【重要】$null だけでなく空文字 "" も「取得失敗」とみなす
            if (-not [string]::IsNullOrWhiteSpace($price.date) -and 
                -not [string]::IsNullOrWhiteSpace($price.nav)) { 
                return $price 
            }
        }

        # 3. 個別サイトで失敗(null/空文字)または設定なしなら、WealthAdvisor(WLT)へ
        return $this.GetPriceFromWLT($code)
    }

    [PSCustomObject] GetPrice([string]$code, [int]$waitMs) {
        if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906')) {
            return [ToshinDAO]::getPriceMUFJ($code)
        }

        $config = [ToshinDAO]::pricesrc[$code]
        if ($null -ne $config) {
            $price = $this.InternalScrape($code, $config.url, $config, $waitMs)
            if (-not [string]::IsNullOrWhiteSpace($price.date) -and 
                -not [string]::IsNullOrWhiteSpace($price.nav)) { 
                return $price 
            }
        }
        return $this.GetPriceFromWLT($code)
    }

    # WealthAdvisor (default) からの取得
    [PSCustomObject] GetPriceFromWLT([string]$code) {
        $config = [ToshinDAO]::pricesrc['default']
        $targetUrl = $config.url + $code
        
        $price = $this.InternalScrape($code, $targetUrl, $config, 0)
        $price.code = $code
        return $price
    }
    
    # 内部スクレイピング処理
    hidden [PSCustomObject] InternalScrape([string]$code, [string]$url, [object]$conf, [int]$waitMs) {
        $selectors = [Collections.Generic.Dictionary[string, string]]::new()
        $selectors.Add("Date", $conf.bpath)
        $selectors.Add("Price", $conf.npath)
        $selectors.Add("Change", $conf.cpath)

        if ($waitMs -gt 0) { Start-Sleep -Milliseconds $waitMs }

        try {
            $raw = $this.scraper.ExtractValuesAsync($url, $selectors).GetAwaiter().GetResult()
            return [ordered]@{
                code = $code
                date = [ToshinDAO]::CleanDate($raw["Date"])
                nav  = [ToshinDAO]::CleanNumber($raw["Price"])
                cmp  = [ToshinDAO]::CleanNumber($raw["Change"])
            }
        }
        catch {
            return [ordered]@{ code = $code; date = $null; nav = $null; cmp = $null }
        }
    }

    # --- ユーティリティ (null判定を厳密に) ---

    static [string] CleanDate([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }
        # 日付に関係ない文字を除去して正規化
        $clean = $text -replace "年|月", "/" -replace "日", ""
        if ($clean -match "[\d/]{7,}") {
            try { return (Get-Date $Matches[0]).ToString("yyyyMMdd") } catch { return $null }
        }
        return $null
    }

    static [string] CleanNumber([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }
        # 数値や符号を抽出
        if ($text -match "[-\d,.]+") { 
            $num = $Matches[0] -replace "," , ""
            # 「-」だけの文字や空文字はnullとして扱う
            if ($num -eq "-" -or $num -eq "") { return $null }
            return $num
        }
        return $null
    }

    static [pscustomobject]getPriceMUFJ([string]$code) {
        $url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/"
        $codetbl = @{'2004022702' = '148106'; '2017022703' = '252653'; '201707310A' = '252845'; '2016012906' = '261385' }
        $url += $codetbl[$code]
        try {
            $res = Invoke-RestMethod -Uri $url -ErrorAction Stop
            return [ordered]@{
                code = $code
                date = $res.datasets[0].base_date
                nav  = $res.datasets[0].nav
                cmp  = $res.datasets[0].cmp_prev_day
            }
        }
        catch {
            return [ordered]@{ code = $code; date = $null; nav = $null; cmp = $null }
        }
    }

    [void]Dispose() {
        if ($this.scraper) { 
            $this.scraper.Dispose() 
            $this.scraper = $null
        }
    }
}

# ─── 以下、関数読み込み・エクスポート部分は変更なし ───
foreach ($folder in @('Common', 'Extensions', 'Private', 'Public')) {
    $targetPath = Join-Path $PSScriptRoot $folder
    if (Test-Path $targetPath) {
        Get-ChildItem "$targetPath\*.ps1" | ForEach-Object { . $_.FullName }
    }
}
$publicFunctions = @()
if (Test-Path "$PSScriptRoot\Public") {
    $publicFunctions = Get-ChildItem "$PSScriptRoot\Public\*.ps1" | ForEach-Object { $_.BaseName }
}
Export-ModuleMember -Function $publicFunctions
if (Get-Command "Enable-ModuleSettings" -ErrorAction SilentlyContinue) { Enable-ModuleSettings }