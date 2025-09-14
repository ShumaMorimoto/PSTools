OlApoTable([object]$folder) {
        $this.folder = $folder
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items.Sort("[Start]")
    }
