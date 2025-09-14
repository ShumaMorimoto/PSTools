GetToken() {
        [OTGMailDAO]::accessToken = [OTGoogleDAO]::GetToken([OTGMailDAO]::scope)
    }
