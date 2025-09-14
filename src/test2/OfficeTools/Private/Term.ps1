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
