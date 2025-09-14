class OTGoogleDAO {
    static $certPswd = "notasecret"

    OTGoogleDAO() {
    }

    static [string]GetToken([string]$scope) {
        $headerJSON = [Ordered]@{
            alg = "RS256"
            typ = "JWT"
        } | ConvertTo-Json -Compress
        $headerBase64 = ConvertTo-Base64URL -text $headerJSON
				
        $iat = [int64]([double]::Parse((get-date -date ([DateTime]::UtcNow) -uformat "%s"), [cultureinfo][system.threading.thread]::currentthread.currentculture))
        $exp = $iat + 59 * 60
        $aud = "https://www.googleapis.com/oauth2/v4/token"
        $claimsJSON = [Ordered]@{
            iss   = [OTConfig]::Settings.Google.iss
            scope = [OTGSheetDAO]::scope
            aud   = $aud
            exp   = $exp
            iat   = $iat
        } | ConvertTo-Json -Compress

        $claimsBase64 = ConvertTo-Base64URL -text $claimsJSON
		
        $googleCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(`
                [OTConfig]::Settings.Google.certPath, `
                [OTGoogleDAO]::certPswd, `
                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable `
        )
        $rsaPrivate = $googleCert.PrivateKey
        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
        $null = $rsa.ImportParameters($rsaPrivate.ExportParameters($true))

        $toSign = [System.Text.Encoding]::UTF8.GetBytes($headerBase64 + "." + $claimsBase64)
        $signature = ConvertTo-Base64URL -Bytes $rsa.SignData($toSign, "SHA256") ## this needs to be converted back to regular text

        # Build request
        $jwt = $headerBase64 + "." + $claimsBase64 + "." + $signature
        $fields = 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=' + $jwt

        # Fetch token
        $response = Invoke-RestMethod -Uri "https://www.googleapis.com/oauth2/v4/token" -Method Post -Body $fields -ContentType "application/x-www-form-urlencoded"

        return $response.access_token
    }

}
