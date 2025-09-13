class Term {
    [datetime] $base
    [datetime] $start
    [datetime] $end
    
    Term([datetime]$_base) {
        $this.base = $_base
        $this.start = Get-Date($_base.toString("yyyy/MM/dd"))
        $this.end = $this.start.addDays(1)
    }
    Term([datetime]$st, [datetime]$ed) {
        $this.base = $st
        $this.start = $st
        $this.end = $ed
    }
    Term([datetime]$_base, [string]$span) {
        # span 1:month, 2:half, 3:year
        $this.base = $_base
        switch ($span) {
            "1" {
                $this.start = Get-Date($_base.toString("yyyy/MM/1"))
                $this.end = $this.start.addMonths(1)
            }
            "2" {
                $diff = switch ($_base.Month) { { (4 -le $_) -and ($_ -le 9) } { 4 }; default { 10 } } 
                $this.start = Get-Date($_base.AddMonths($diff - $_base.Month).toString("yyyy/MM/1"))
                $this.end = $this.start.AddMonths(6)
            }
            "3" {
                $diff = switch ($_base.Month) { { 4 -le $_ } { 4 }; default { -8 } } 
                $this.start = Get-Date($_base.AddMonths($diff - $_base.Month).toString("yyyy/MM/1"))
                $this.end = $this.start.AddMonths(12)
            }
            default {}
        } 
    }
    [boolean] Contains([datetime]$dt) {
        return ($this.start -le $dt) -and ($dt -lt $this.end)
    }
    [Term] ThisMonth() {
        return New-Object Term($this.base, 1)
    }
    [Term] PrevMonth() {
        return New-Object Term($this.base.addMonts(-1), 1)
    }
    [Term] Half() {
        return New-Object Term($this.base, 2)
    }
    [Term[]] HalfMonths() {
        $diff = switch ($this.base.Month) { { (4 -le $_) -and ($_ -le 9) } { 4 }; default { 10 } } 
        $diff -= $this.base.Month
        return $diff..0 | ForEach-Object { New-Object Term($this.base.addmonths($_), 1) }
    }
}
