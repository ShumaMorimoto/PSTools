Search([string]$base_url, [string]$title) {
        [ConfluDAO]::getPAT() | Out-Null      
        $url = $base_url + "?title=" + $title
        $response = Invoke-RestMethod -Uri $url -Method "GET" -Headers ([ConfluDAO]::headers)      
        $id = ""
        if ($response.results.Count -gt 0 ) {
            $id = $response.results.id
        }
        return $id
    }
