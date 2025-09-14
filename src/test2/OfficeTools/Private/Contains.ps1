Contains([datetime]$dt) {
        return ($this.start -le $dt) -and ($dt -lt $this.end)
    }
