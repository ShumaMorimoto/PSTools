formatDT ([Object]$dt) {
        if ($dt -is [datetime]) { $dt = $dt.toString("yyyy/M/d HH:mm") } 
        return $dt
    }
