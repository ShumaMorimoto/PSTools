function Invoke-WebRequest2 {
    [OutputType([HtmlAgilityPack.HtmlDocument])]
    param(
        [string]$url,
        [int]$waitMs,
        [string]$xpath
    )

    # 現在のコンソールのエンコーディングを一時的に保存
    $originalEncoding = [System.Console]::OutputEncoding

    try {
        # コンソールの出力エンコーディングをUTF-8に設定
        [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        # Node.js スクリプトの引数を構築
        $args = @("$PSScriptRoot\scripts\render.js", $url)

        if ($PSBoundParameters.ContainsKey('waitMs')) {
            $args += @("--wait", $waitMs)
        }

        if ($PSBoundParameters.ContainsKey('xpath')) {
            $args += @("--xpath", $xpath)
        }

        # Node.js スクリプトを実行し、HTMLを取得
        $html = node $args | Out-String
    }
    finally {
        # 元のエンコーディングに戻す
        [System.Console]::OutputEncoding = $originalEncoding
    }

    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($html)

    return $doc
}
