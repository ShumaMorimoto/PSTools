SetCnflToken() {
        $base64AuthInfo = [Convert]::ToBase64String( `
                [Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f `
                    ([OTConfig]::Settings.Credential.id -replace "cu.nri.co.jp", "nri.co.jp"), `
                        [OTConfig]::password))`
        )

        $headers = @{
            Authorization  = ("Basic {0}" -f $base64AuthInfo)
            "Content-Type" = "application/json; charset=UTF-8"
        }   
        $body = @{
            name               = "myToken"
            expirationDuration = 90
        }
        $json = ConvertTo-JSON -Compress $body
        $tokens = Invoke-RestMethod -Uri ([OTConfig]::Settings.Confluence.url) -Body $json -Method "POST" -Headers ($headers)
        [OTConfig]::Settings.Confluence.tokens = $tokens
        [OTConfig]::Save()
        return $tokens
    }
