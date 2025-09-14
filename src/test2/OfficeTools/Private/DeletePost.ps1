DeletePost($post_id) {
        $url = $this.base_url + "/posts/" + $post_id 
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "DEL"
        return $response
    }
