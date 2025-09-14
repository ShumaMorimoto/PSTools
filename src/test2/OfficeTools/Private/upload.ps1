upload([String]$filePath) {
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
