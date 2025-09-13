class ConfluDAO : OTDomDAO {
    static [object] $headers = @{
        "Authorization" = "Bear $([OTConfig]::Settings.Confluence.tokens.rawToken)"
        "Content-Type"  = "application/json; charset=UTF-8"
    }
    static [string] $dtd = @"
<!DOCTYPE page[
<!ENTITY nbsp "&#160;">
<!ENTITY lArr "&#8656;">
<!ENTITY uArr "&#8657;">
<!ENTITY rArr "&#8658;">
<!ENTITY dArr "&#8659;">
<!ENTITY hArr "&#8660;">
<!ENTITY vArr "&#8661;">
<!ENTITY nwArr "&#8662;">
<!ENTITY neArr "&#8663;">
<!ENTITY seArr "&#8664;">
<!ENTITY swArr "&#8665;">
<!ENTITY larr "&#8592;">
<!ENTITY uarr "&#8593;">
<!ENTITY rarr "&#8594;">
<!ENTITY darr "&#8595;">
<!ENTITY harr "&#8596;">
<!ENTITY varr "&#8597;">
<!ENTITY nwarr "&#8598;">
<!ENTITY nearr "&#8599;">
<!ENTITY searr "&#8600;">
<!ENTITY swarr "&#8601;">
<!ENTITY times "&#215;">
<!ATTLIST page xmlns:ci CDATA #FIXED "ci">
<!ATTLIST page xmlns:li CDATA #FIXED "li">
<!ATTLIST page xmlns:ac CDATA #FIXED "ac">
<!ATTLIST page xmlns:ri CDATA #FIXED "ri">
]>
"@
    [string] $page
    [int] $vernum
    [string] $title
    [xml] $doc
    [string] $base_url
    [string] $page_id
    [object] $attachments = @{}

    ConfluDAO([string]$base_url, [string] $page_id) {
        [ConfluDAO]::getPAT() | Out-Null
        $this.Load($base_url, $page_id)
    }
    ConfluDAO() {
        [ConfluDAO]::getPAT() | Out-Null
    }
    ConfluDAO([string]$base_url, [string] $space_key, [string] $parent_id, [string]$title, [string]$page) {
        $this.page_id = [ConfluDAO]::Search($base_url, $title)
        
        if ($this.page_id -eq "") {
            $this.page_id = [ConfluDAO]::Create($base_url, $space_key, $parent_id, $title, $page)
        }
        $this.Load($base_url, $this.page_id)
    }
    static [string]Create([string]$base_url, [string] $space_key, [string] $parent_id, [string]$title, [string]$page) {
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
    static [string]Search([string]$base_url, [string]$title) {
        [ConfluDAO]::getPAT() | Out-Null      
        $url = $base_url + "?title=" + $title
        $response = Invoke-RestMethod -Uri $url -Method "GET" -Headers ([ConfluDAO]::headers)      
        $id = ""
        if ($response.results.Count -gt 0 ) {
            $id = $response.results.id
        }
        return $id
    }
    [boolean]Load([string]$base_url, [string]$page_id) {
        $this.base_url = $base_url
        $this.page_id = $page_id
        $url = $this.base_url + "/" + $this.page_id + "?expand=body.storage,version"

        $response = Invoke-RestMethod -Uri $url -Method "GET" -Headers ([ConfluDAO]::headers)
        $this.page = $response.body.storage.value
        $this.vernum = $response.version.number
        $this.title = $response.title
                
        $this.LoadXml([ConfluDAO]::toXML($this.page))           

        $url = $this.base_url + "/" + $this.page_id + "/child/attachment"
        $_headers = @{
            "Authorization"     = "Bearer " + [ConfluDAO]::getPAT()
            "X-Atlassian-Token" = "no-check"
        }
        $response = Invoke-RestMethod -Uri $url -Method "GET" -Headers $_headers
        $response.results | ForEach-Object { $this.attachments.Add($_.title, $_.id) }

        return $true
    }
    [Object] Save() {
        $url = $this.base_url + "/" + $this.page_id

        $payload = @{
            title   = $this.title
            type    = "page"
            version = @{
                number = $this.vernum + 1
            }
            body    = @{
                storage = @{
                    representation = "storage"
                    value          = $this.page.innerXML
                }
            }
        }
        $json = ConvertTo-JSON -Compress $payload
        $response = Invoke-RestMethod -Uri $url -Body $json -Method "PUT" -Headers ([ConfluDAO]::headers) -ErrorVariable RespErr
        $this.vernum ++
        
        return $payload
    }
    [Object] upload([String]$filePath) {
        $url = $this.base_url + "/" + $this.page_id + "/child/attachment"
        $name = $filePath -replace '^.+\\([^\\]+)$', '$1' 

        $_headers = @{
            "Authorization"     = "Bearer " + [ConfluDAO]::getPAT()
            "X-Atlassian-Token" = "no-check"
        }

        if ($this.attachments.ContainsKey($name)) {
            $url = "$url/" + $this.attachments[$name] + "/data"       
        }

        $Form = @{ file = Get-ChildItem $filePath; comment = "UPDATE" }
        $response = Invoke-RestMethod -Uri $url -Method "POST" -Headers $_headers -Form $Form
  
        return $response
    }
    static [string] toXML($value) {
        return([ConfluDAO]::dtd + "<page>$value</page>")
    }
    static [string] getPAT() {
        $tokens = [OTConfig]::GetCnflToken()
        [ConfluDAO]::headers = @{
            "Authorization" = "Bearer " + $tokens.rawToken
            "Content-Type"  = "application/json; charset=UTF-8"
        }
        return $tokens.rawToken
    }
}
