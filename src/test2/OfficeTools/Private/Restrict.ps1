Restrict([Object]$keywords) { 
        $this.items = [OTOutlookDAO]::filterItems($this.items, $keywords)
        return $this.items
    }
