GetUsers($ids) {
        $url = $this.base_url + "/users/ids" 
        $json = ConvertTo-JSON -Compress $ids
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "POST" -Body $json
        return $response
    }
