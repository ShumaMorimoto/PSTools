Create([string]$base_url, [string] $space_key, [string] $parent_id, [string]$title, [string]$page) {
        [ConfluDAO]::getPAT() | Out-Null      
        $payload = @{
            title     = $title
            space     = @{key = $space_key }
            type      = "page"
            ancestors = @(@{id = $parent_id })
            body      = @{
                storage = @{
                    representation = "storage"
                    value          = $page
                }
            }
        }
        $json = ConvertTo-JSON -Compress $payload
        $response = Invoke-RestMethod -Uri $base_url -Body $json -Method "POST" -Headers ([ConfluDAO]::headers) -ErrorVariable RespErr   
        return $response.id
    }
