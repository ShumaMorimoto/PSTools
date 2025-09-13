class MattermostDAO {
    static [object] $headers = @{
        "Authorization" = "Bearer $pat"
        "Content-Type"  = "application/json; charset=UTF-8"
    }
    [string] $base_url
    [object] $me
    [object] $users
    [object] $posts
    $selectheader = @(
        @{label = "ID"; expression = { $_.id } } ,
        @{label = "日付"; expression = { (Get-Date("1970/1/1")).AddMilliseconds($_.create_at ) } },
        @{label = "投稿者"; expression = { $uid = $_.user_id; ($users | Where-Object { $_.id -eq $uid }).first_name } }
        @{label = "投稿内容"; expression = { $_.message } }
    )
    MattermostDAO([string]$base_url) {
        [MattermostDAO]::getPAT() | Out-Null
        $this.base_url = $base_url
        $this.me = $this.GetMe()
    }
    MattermostDAO() {
        [MattermostDAO]::getPAT() | Out-Null
    }
    [Object] Post($channel_id, $message) {
        $url = $this.base_url + "/posts"
        $payload = @{
            "channel_id" = $channel_id
            "message"    = $message
        }
        $json = ConvertTo-JSON -Compress $payload
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "POST" -Body $json
        return $payload
    }
    [Object] GetPosts($channel_id) {
        $url = $this.base_url + "/channels/" + $channel_id + "/posts"   
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "GET"
        $this.posts = $response.order | ForEach-Object { $response.posts.$_ } 
        $this.users = $this.GetUsers(($this.posts.user_id | Select-Object -Unique))
        return $this.posts
    }
    [Object] DeletePost($post_id) {
        $url = $this.base_url + "/posts/" + $post_id 
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "DEL"
        return $response
    }
    [Object] GetUsers($ids) {
        $url = $this.base_url + "/users/ids" 
        $json = ConvertTo-JSON -Compress $ids
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "POST" -Body $json
        return $response
    }
    [Object] GetMe() {
        $url = $this.base_url + "/users/me" 
        $this.me = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "GET" 
        return $this.me
    }
    static [string] getPAT() {
        $pat = [OTConfig]::Settings.Mattermost.pat
        [MattermostDAO]::headers = @{
            "Authorization" = "Bearer " + $pat
            "Content-Type"  = "application/json; charset=UTF-8"
        }
        return $pat
    }
}
