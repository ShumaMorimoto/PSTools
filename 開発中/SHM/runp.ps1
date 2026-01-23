# 自分のIPアドレスを自動取得（手書きの手間を省く場合）
#$myIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -Match 'Wi-Fi|Ethernet' | Select-Object -ExpandProperty IPAddress -First 1)

$myIp = 127.0.0.1

Start-PodeServer {
    # 1. 「＊」をやめ、特定のIPアドレスを指定
    # 2. httpsでアクセス（自己署名証明書を自動生成）
    Add-PodeEndpoint -Address 192.168.0.13 -Port 8080 -Protocol Https -SelfSigned

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # 4. ページ内のリンクもmDNS名（.local）にする
        # ※相対パスを使えば自動的にmDNS名を引き継ぎますが、
        # あえて絶対パスで書く場合も.localで記述して問題ありません。
        $html = @"
        <html>
        <body>
            <h1>Secure Local Site</h1>
            <p>Your IP: $myIp</p>
            <a href="https://pc-name.local/subpage">Next Page (mDNS Link)</a>
        </body>
        </html>
"@
        Write-PodeHtmlResponse -Value $html
    }
}