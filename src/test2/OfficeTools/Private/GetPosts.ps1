GetPosts($channel_id) {
        $url = $this.base_url + "/channels/" + $channel_id + "/posts"   
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "GET"
        $this.posts = $response.order | ForEach-Object { $response.posts.$_ } 
        $this.users = $this.GetUsers(($this.posts.user_id | Select-Object -Unique))
        return $this.posts
    }
