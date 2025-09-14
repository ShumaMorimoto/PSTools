GetApos([int]$term) {
        $date = Get-Date  
        return $this.GetApos($date.toString("yyyy/M/d 00:00"), $date.adddays($term).toString("yyyy/M/d 00:00"))
    }
