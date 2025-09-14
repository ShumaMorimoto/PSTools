ConfluDAO([string]$base_url, [string] $space_key, [string] $parent_id, [string]$title, [string]$page) {
        $this.page_id = [ConfluDAO]::Search($base_url, $title)
        
        if ($this.page_id -eq "") {
            $this.page_id = [ConfluDAO]::Create($base_url, $space_key, $parent_id, $title, $page)
        }
        $this.Load($base_url, $this.page_id)
    }
