CreateEvent([datetime] $date) { 
        $item = $this.items.Add()
        $item.Start = $date.toString("yyy/M/d 00:00")
        $item.End = $date.addDays(1).toString("yyy/M/d 00:00")
        $item.AllDayEvent = $true
        return $item
    }
