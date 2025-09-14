GetMe() {
        $url = $this.base_url + "/users/me" 
        $this.me = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "GET" 
        return $this.me
    }
