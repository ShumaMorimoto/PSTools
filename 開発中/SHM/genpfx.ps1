# 証明書作成（localhostとLAN IP両対応）
$cert = New-SelfSignedCertificate -DnsName "localhost", "192.168.0.23" `
    -CertStoreLocation "cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddYears(5)

# .pfxエクスポート（パスワードは任意、空でもOK）
$pwd = ConvertTo-SecureString -String "shuma" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath "D:\tool\tmp\selfcert.pfx" -Password $pwd