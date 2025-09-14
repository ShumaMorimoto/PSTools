GetTables() {
        $this.getElementsByTagName("table") | ForEach-Object { $this.AppendTable($_) | Out-Null }
        return $this.tables
    }
