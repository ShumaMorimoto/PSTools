GetCnflToken() {
        $tokens = [OTConfig]::Settings.Confluence.tokens
        if ($null -eq $tokens) {
            $tokens = [OTConfig]::SetCnflToken()
        }
        if (
            ($null -eq $tokens.expiringAt) -or `
            ([Datetime]($tokens.expiringAt) -lt (Get-Date).AddDays(20))
        ) {
            $tokens = [OTConfig]::UpdateCnflToken($tokens.rawToken)
        }
        return $tokens
    }
