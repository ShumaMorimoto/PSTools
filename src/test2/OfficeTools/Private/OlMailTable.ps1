OlMailTable([object]$folder) {
        $this.folder = $folder
        $this.items = $this.folder.items
        $this.items.Sort("[ReceivedTime]")
    }
