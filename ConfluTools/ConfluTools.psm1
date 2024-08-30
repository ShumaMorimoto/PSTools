[string] $token = "MTAwNjk4NTA1MTcwOltz9manllOlRKkh3oAyY/xyX/z/"

    class ConfluDAO {
    [string] $page
    [int] $vernum
    [string] $title
    [xml] $doc
    [string] $base_url
    [string] $page_id
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json; charset=UTF-8"
    }
    ConfluDAO([string]$base_url, [string] $page_id) {
        $this.Load($base_url, $page_id)
    }
    ConfluDAO() {
    }
    [boolean]Load([string]$base_url, [string]$page_id) {
        $this.base_url = $base_url
        $this.page_id = $page_id
        $url = $this.base_url + $this.page_id + "?expand=body.storage,version"

        $response = Invoke-WebRequest -Uri $url -Method "GET" -Headers $this.headers

        $content = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($response.Content))
        $json = ConvertFrom-JSON $content
        $this.page = $json.body.storage.value
        $this.vernum = $json.version.number
        $this.title = $json.title
                
        $this.doc = New-Object System.Xml.XmlDocument       
        $this.doc.LoadXml([ConfluDAO]::toXML($this.page))           

        return $true
    }
    [Object] Save() {
        $url = $this.base_url + $this.page_id

        $payload = @{
            title   = $this.title
            type    = "page"
            version = @{
                number = $this.vernum + 1
            }
            body    = @{
                storage = @{
                    representation = "storage"
                    value          = $this.doc.page.innerXML
                }
            }
        }
        $json = ConvertTo-JSON -Compress $payload
        $response = Invoke-RestMethod -Uri $url -Body $json -Method "PUT" -Headers $this.headers -ErrorVariable RespErr
        $this.vernum ++
        
        return $payload
    }
    static [string] toXML($value) {
        $header = '<!DOCTYPE page[<!ENTITY nbsp "&#160;">]>'
        return($header+'<page xmlns:ci="ci" xmlns:li="li" xmlns:ac="ac" xmlns:ri="ri">'+$value+'</page>')           
    }
} 
