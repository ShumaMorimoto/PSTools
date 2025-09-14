AppendWeeklyTrigger ([string]$TriggerTime, [string[]]$days) {
        $ns = $this.xml.Task.NamespaceURI
            
        # 新しいトリガを作成
        $newTrigger = $this.xml.CreateElement("CalendarTrigger", $ns)
     
        $startBoundary = $this.xml.CreateElement("StartBoundary", $ns)
        $startBoundary.InnerText = ([datetime]$TriggerTime).ToString("yyyy-MM-ddTHH:mm:ss")
        $newTrigger.AppendChild($startBoundary)
    
        $scheduleByWeek = $this.xml.CreateElement("ScheduleByWeek", $ns)

        $weeksInterval = $this.xml.CreateElement("WeeksInterval", $ns)
        $weeksInterval.InnerText = "1"
        $scheduleByWeek.AppendChild($weeksInterval)

        $daysOfWeek = $this.xml.CreateElement("DaysOfWeek", $ns)
        $days | ForEach-Object {
            $day = $this.xml.CreateElement($_, $ns)
            $daysOfWeek.AppendChild($day)
        }
        $scheduleByWeek.AppendChild($daysOfWeek)

        $newTrigger.AppendChild($scheduleByWeek)
        
        # トリガを追加
        $this.xml.SelectSingleNode("//*[local-name()='Triggers']").AppendChild($newTrigger)
    }
