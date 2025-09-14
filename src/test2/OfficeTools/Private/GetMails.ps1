GetMails([int]$term) {
        $date = Get-Date
        return $this.GetMails($date.addDays(-$term).toString("yyyy/M/d 23:59"), $date.toString("yyyy/M/d 23:59"))
    }
