class ConfluDAO {
    [string] $page
    [int] $vernum
    [string] $title
    [xml] $doc
    [string] $base_url
    [string] $page_id
    #    [string] $token = "MTAwNjk4NTA1MTcwOltz9manllOlRKkh3oAyY/xyX/z/"
    [string] $token = "ATATT3xFfGF0-DE_7AWjU81CaeXyz4HZghwPc5bdjtb7gXYyA2UDZHQOEEWLLS4zgtQwqsedLgzyTNMZzFwD1pbhjKTF48hRwnAfo6l2jysvkGKZCzqPkl9Ktavu0eub-mxbRK1__Ped5aT5gYmQmg2IdhDRBuhOv0w2LIBNTxPm4q0du3GIcnA=5E67F475"
    $headers = @{
        "Authorization" = "Bearer $($this.token)"
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

        #       $response = Invoke-RestMethod -Uri $url -Method "GET" -Headers $this.headers
        #       $this.page=$response.body.storage.value
        #       $this.vernum=$response.version.number
        #       $this.title=$response.title

        $this.page = "<p class='wrapped'>こんにちは<BR></p>"

        $this.doc = New-Object System.Xml.XmlDocument       
        $this.doc.LoadXml('<page xmlns:ci="ci" xmlns:li="li">' + $this.page + '</page>')           

        return $true
    }
    [Object] Save() {
        $url = $this.baseUrl + $this.pageId

        $payload = @{
            title   = $this.title
            type    = "page"
            version = @{
                number = $this.vernum + 1
            }
            body    = @{
                storage = @{
                    representation = "storage"
                    value          = this.doc.page.innerXML
                }
            }
        }
        $json = ConvertTo-JSON -Compress $payload

        #        $response = Invoke-RestMethod -Uri $url -Body $json -Method "PUT" -Headers $this.headers -ErrorVariable RespErr
        return $payload
    }
} 
