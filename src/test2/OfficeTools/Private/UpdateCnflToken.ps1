UpdateCnflToken([string]$token) {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type"  = "application/json; charset=UTF-8"
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
