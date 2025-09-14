GetUnreadMails([int]$term) {
        $date = Get-Date
        return $this.GetUnreadMails($date.addDays(-$term).toString("yyyy/M/d 23:59"), $date.toString("yyyy/M/d 23:59"))
    }
