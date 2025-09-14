Post($channel_id, $message) {
        $url = $this.base_url + "/posts"
        $payload = @{
            "channel_id" = $channel_id
            "message"    = $message
        }
        $json = ConvertTo-JSON -Compress $payload
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "POST" -Body $json
        return $payload
    }
