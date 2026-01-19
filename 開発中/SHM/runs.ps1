$pfxPath = 'D:\tool\Repository\PSTools\開発中\SHM\selfcert.pfx'

# ファイルの存在チェック
if (-not (Test-Path $pfxPath)) {
    Write-Error "証明書ファイルが [$pfxPath] に見つかりません！パスを確認してください。"
    return
}

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8443 -Protocol Https `
        -Certificate $pfxPath `
        -CertificatePassword 'shuma'

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Status = "Success"; Path = $pfxPath }
    }
}