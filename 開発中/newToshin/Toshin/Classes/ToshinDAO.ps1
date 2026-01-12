class ToshinDAO : IDisposable {
    hidden [object]$scraper  # 型を[object]にすることでパース時のチェックを回避
    hidden static [hashtable]$pricesrc = @{}

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
        if ($code -in ('2004022702', '2017022703', '201707310A', '2016012906')) {
            return [ToshinDAO]::getPriceMUFJ($code)
        }

        $config = [ToshinDAO]::pricesrc[$code]
        if ($null -eq $config) { 
            $config = [ToshinDAO]::pricesrc['default']
            $targetUrl = $config.url + $code
        } else {
            $targetUrl = $config.url
        }

        # 辞書型などの標準的なジェネリック型は直接書いても問題なし
        $selectors = [Collections.Generic.Dictionary[string,string]]::new()
        $selectors.Add("Date",   $config.bpath)
        $selectors.Add("Price",  $config.npath)
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

    static [pscustomobject]getPriceMUFJ([string]$code) {
        $url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/$($code)"
        # ※MUFJ専用コード変換テーブルが必要ならここに配置
        $res = Invoke-RestMethod -Uri $url
        return [ordered]@{
            code = $code
            date = $res.datasets[0].base_date
            nav  = $res.datasets[0].nav
            cmp  = $res.datasets[0].cmp_prev_day
        }
    }

    [void]Dispose() {
        if ($this.scraper) { $this.scraper.Dispose() }
    }
}