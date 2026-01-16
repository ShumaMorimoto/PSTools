class ToshinDAO : IDisposable {
    hidden [object]$scraper  # 型を[object]にすることでパース時のチェックを回避
    hidden static [hashtable]$pricesrc = @{}

    # ToshinDAOクラスの冒頭に追加
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

    ToshinDAO() {
        # 1. configフォルダから価格定義をロード
        if ([ToshinDAO]::pricesrc.Count -eq 0) {
            $configFile = Join-Path $PSScriptRoot "config/PriceSources.json"
            if (Test-Path $configFile) {
                $json = Get-Content $configFile -Raw | ConvertFrom-Json
                foreach ($prop in $json.psobject.Properties) {
                    [ToshinDAO]::pricesrc[$prop.Name] = $prop.Value
                }
            }
        }

        # 2. 型を文字列から動的に取得してインスタンス化
        # [GenericScraper.WebScraperCore]::new() と書くとパースエラーになるため
        $typeName = "GenericScraper.WebScraperCore"
        $type = [System.Type]::GetType($typeName)
        if ($null -eq $type) {
            throw "DLLがロードされていないか、型 [$typeName] が見つかりません。"
        }

        $this.scraper = [Activator]::CreateInstance($type)
        $this.scraper.InitializeAsync($true).GetAwaiter().GetResult()
    }

    [PSCustomObject] GetPrice([string]$code) {
        # MUFG系判定
        if ([ToshinDAO]::mufgCodeMap.ContainsKey($code)) {
            return [ToshinDAO]::getPriceMUFJ($code)
        }

        # NAM (ニッセイアセット) CSV系
        # ニッセイゴールド(122407)など、NAMのコード体系（6桁）の場合
        if ([ToshinDAO]::namCodeMap.ContainsKey($code)) {
            $namInternalCode = [ToshinDAO]::namCodeMap[$code]
            return [ToshinDAO]::getPriceNAM($namInternalCode)
        }

        $config = [ToshinDAO]::pricesrc[$code]
        if ($null -eq $config) { 
            $config = [ToshinDAO]::pricesrc['default']
            $targetUrl = $config.url + $code
        }
        else {
            $targetUrl = $config.url
        }

        # 辞書型などの標準的なジェネリック型は直接書いても問題なし
        $selectors = [Collections.Generic.Dictionary[string, string]]::new()
        $selectors.Add("Date", $config.bpath)
        $selectors.Add("Price", $config.npath)
        $selectors.Add("Change", $config.cpath)

        $raw = $this.scraper.ExtractValuesAsync($targetUrl, $selectors).GetAwaiter().GetResult()

        return [ordered]@{
            code = $code
            date = [ToshinDAO]::CleanDate($raw["Date"])
            nav  = [ToshinDAO]::CleanNumber($raw["Price"])
            cmp  = [ToshinDAO]::CleanNumber($raw["Change"])
        }
    }

    static [string] CleanDate([string]$text) {
        if ($text -replace "年|月", "/" -match "[\d/]{7,}") {
            try { return (Get-Date $Matches[0]).ToString("yyyyMMdd") } catch { return $null }
        }
        return $null
    }

    static [string] CleanNumber([string]$text) {
        if ($text -match "[-\d,.]+") { return $Matches[0] }
        return $null
    }

    # --- 追加: ニッセイアセットマネジメント専用メソッド ---
    static [pscustomobject] getPriceNAM([string]$code) {
        try {
            $url = "https://www.nam.co.jp/fundinfo/data/csv.php?fund_code=$code"
            $res = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
            
            # Shift-JISでデコード
            $encoding = [System.Text.Encoding]::GetEncoding("Shift-JIS")
            $csvText = $encoding.GetString($res.Content)
            
            # 1行目：ヘッダ, 2行目：最新データ (日付形式: 2026年01月14日)
            $lines = $csvText.Split("`n") | Where-Object { $_ -match '^\d{4}年\d{2}月\d{2}日' }
            $latest = $lines | Select-Object -First 1
            
            if ($latest -match '^([^,]+),[^,]+,(\d+),[^,]+,[^,]+,([+-]?\d+)') {
                return [ordered]@{
                    code = $code
                    date = [ToshinDAO]::CleanDate($matches[1]) # "2026年01月14日" -> "20260114"
                    nav  = $matches[2]
                    cmp  = $matches[3]
                }
            }
        }
        catch {
            Write-Error "NAM価格取得失敗: $code ($($_.Exception.Message))"
        }
        return $null
    }

    static [pscustomobject] getPriceMUFJ([string]$code) {
        # メソッド内のテーブルは不要になり、外部の mufgCodeMap を参照
        $mufgCode = [ToshinDAO]::mufgCodeMap[$code]
        $url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/$mufgCode"
        
        $response = Invoke-RestMethod -Uri $url -Method 'GET' -ContentType 'application/json; charset=utf-8'
        $data = $response.datasets[0]

        return [ordered]@{
            code = $code
            date = $data.base_date -replace '-', ''  # 2026-01-14 -> 20260114
            nav  = $data.nav
            cmp  = $data.cmp_prev_day
        }
    }

    [void]Dispose() {
        if ($this.scraper) { $this.scraper.Dispose() }
    }
}