ExTable([object]$range) {
        $this.sheet = $range.WorkSheet
        $this.range = $range
        $this.oHeader = $this.GetHeader()
    }
