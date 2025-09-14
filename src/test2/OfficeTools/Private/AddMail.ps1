AddMail([object]$item) {
        $item | ForEach-Object { $_.Move($this.folder) }
    }
