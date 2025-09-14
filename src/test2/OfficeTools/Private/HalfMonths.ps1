HalfMonths() {
        $diff = switch ($this.base.Month) { { (4 -le $_) -and ($_ -le 9) } { 4 }; default { 10 } } 
        $diff -= $this.base.Month
        return $diff..0 | ForEach-Object { New-Object Term($this.base.addmonths($_), 1) }
    }
