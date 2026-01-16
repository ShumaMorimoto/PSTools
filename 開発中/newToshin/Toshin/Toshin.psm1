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

    # --- 変換テーブル定義 ---
    hidden static [hashtable]$namCodeMap = @{
        "2013121001" = "121332"  # ニッセイ外国株式インデックス（購入・換金手数料なし）
        "2024043003" = "122407"  # ニッセイゴールドファンド（為替ヘッジなし）
        "2011110102" = "121117"  # ニッセイグローバル好配当株式プラス
    }
    hidden static [hashtable]$mufgCodeMap = @{
        "2004022702" = "148106"
        "2017022703" = "252653"
        "201707310A" = "252845"
        "2016012906" = "261385"
    }

    # --- コンストラクタ ---

    ToshinDAO() {
        $this.Init($true)
    }

    ToshinDAO([bool]$isHeadless) {
        $this.Init($isHeadless)
    }

    hidden [void] Init([bool]$isHeadless) {
        if ([ToshinDAO]::pricesrc.Count -eq 0) {
            $configFile = Join-Path $PSScriptRoot "config\PriceSources.json"
            if (Test-Path $configFile) {
                $json = Get-Content $configFile -Raw | ConvertFrom-Json
                foreach ($prop in $json.psobject.Properties) {
                    [ToshinDAO]::pricesrc[$prop.Name] = $prop.Value
                }
            }
        }

        $typeName = "GenericScraper.WebScraperCore"
        $type = [AppDomain]::CurrentDomain.GetAssemblies() | 
        ForEach-Object { $_.GetType($typeName) } | 
        Where-Object { $null -ne $_ } | Select-Object -First 1

        if ($null -eq $type) {
            throw "型 [$typeName] が見つかりません。DLLを確認してください。"
        }

        $this.scraper = [Activator]::CreateInstance($type)
        $this.scraper.InitializeAsync($isHeadless).GetAwaiter().GetResult()
    }
    
    # --- 価格取得メソッド群 ---

    [PSCustomObject] GetPrice([string]$code) {
        return $this.GetPrice($code, 0)
    }

    [PSCustomObject] GetPrice([string]$code, [int]$waitMs) {
        # 1. MUFG系判定
        if ([ToshinDAO]::mufgCodeMap.ContainsKey($code)) {
            return [ToshinDAO]::getPriceMUFJ($code)
        }

        # 2. NAM系判定
        if ([ToshinDAO]::namCodeMap.ContainsKey($code)) {
            $namInternalCode = [ToshinDAO]::namCodeMap[$code]
            return [ToshinDAO]::getPriceNAM($namInternalCode)
        }

        # 3. 直接 6桁コード(NAM等)が指定された場合
        if ($code -match '^\d{6}$') {
            return [ToshinDAO]::getPriceNAM($code)
        }

        # 4. 個別サイトでのスクレイピング試行
        $config = [ToshinDAO]::pricesrc[$code]
        if ($null -ne $config) {
            $price = $this.InternalScrape($code, $config.url, $config, $waitMs)
            if (-not [string]::IsNullOrWhiteSpace($price.date) -and 
                -not [string]::IsNullOrWhiteSpace($price.nav)) { 
                return $price 
            }
        }

        # 5. 失敗時はWealthAdvisor(WLT)へ
        return $this.GetPriceFromWLT($code)
    }

    [PSCustomObject] GetPriceFromWLT([string]$code) {
        $config = [ToshinDAO]::pricesrc['default']
        $targetUrl = $config.url + $code
        $price = $this.InternalScrape($code, $targetUrl, $config, 0)
        $price.code = $code
        return $price
    }
    
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

    # --- 専用取得ロジック (API/CSV) ---

    static [pscustomobject] getPriceNAM([string]$code) {
        try {
            $url = "https://www.nam.co.jp/fundinfo/data/csv.php?fund_code=$code"
            $res = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
            
            $encoding = [System.Text.Encoding]::GetEncoding("Shift-JIS")
            $csvText = $encoding.GetString($res.Content)
            
            # 日付で始まる行のうち最新の1行を取得
            $latest = $csvText.Split("`n") | Where-Object { $_ -match '^\d{4}年\d{2}月\d{2}日' } | Select-Object -First 1
            
            if ($latest -match '^([^,]+),[^,]+,(\d+),[^,]+,[^,]+,([+-]?\d+)') {
                return [ordered]@{
                    code = $code
                    date = [ToshinDAO]::CleanDate($matches[1])
                    nav  = $matches[2]
                    cmp  = $matches[3]
                }
            }
        } catch {}
        return [ordered]@{ code = $code; date = $null; nav = $null; cmp = $null }
    }

    static [pscustomobject] getPriceMUFJ([string]$code) {
        $mufgCode = [ToshinDAO]::mufgCodeMap[$code]
        $url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/$mufgCode"
        try {
            $res = Invoke-RestMethod -Uri $url -ErrorAction Stop
            $data = $res.datasets[0]
            return [ordered]@{
                code = $code
                date = $data.base_date -replace '-', ''
                nav  = $data.nav
                cmp  = $data.cmp_prev_day
            }
        }
        catch {
            return [ordered]@{ code = $code; date = $null; nav = $null; cmp = $null }
        }
    }

    # --- ユーティリティ ---

    static [string] CleanDate([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }
        $clean = $text -replace "年|月", "/" -replace "日", ""
        if ($clean -match "[\d/]{7,}") {
            try { return (Get-Date $Matches[0]).ToString("yyyyMMdd") } catch { return $null }
        }
        return $null
    }

    static [string] CleanNumber([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }
        if ($text -match "[-\d,.]+") { 
            $num = $Matches[0] -replace "," , ""
            if ($num -eq "-" -or $num -eq "") { return $null }
            return $num
        }
        return $null
    }

    [void]Dispose() {
        if ($this.scraper) { 
            $this.scraper.Dispose() 
            $this.scraper = $null
        }
    }
}

# ─── 以下、モジュールエクスポート ───
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