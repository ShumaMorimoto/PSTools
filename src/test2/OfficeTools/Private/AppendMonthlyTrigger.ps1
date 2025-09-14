AppendMonthlyTrigger ([string]$TriggerTime, [string[]]$Days) {
        $ns = $this.xml.Task.NamespaceURI
            
        # 新しいトリガを作成
        $newTrigger = $this.xml.CreateElement("CalendarTrigger", $ns)
     
        $startBoundary = $this.xml.CreateElement("StartBoundary", $ns)
        $startBoundary.InnerText = ([datetime]$TriggerTime).ToString("yyyy-MM-ddTHH:mm:ss")
        $newTrigger.AppendChild($startBoundary)
    
        $scheduleByMonth = $this.xml.CreateElement("ScheduleByMonth", $ns)
        $daysOfMonth = $this.xml.CreateElement("DaysOfMonth", $ns)
        $days | ForEach-Object {
            $day = $this.xml.CreateElement("Day", $ns)
            $day.InnerText = $_
            $daysOfMonth.AppendChild($day)
        }
        $scheduleByMonth.AppendChild($daysOfMonth)
        $months = $this.xml.CreateElement("Months", $ns)
        ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"
    ) | ForEach-Object {
            $month = $this.xml.CreateElement($_, $ns)
            $months.AppendChild($month)
        }
        $scheduleByMonth.AppendChild($months)
        $newTrigger.AppendChild($scheduleByMonth)
        
        # トリガを追加
        $this.xml.SelectSingleNode("//*[local-name()='Triggers']").AppendChild($newTrigger)
    }
