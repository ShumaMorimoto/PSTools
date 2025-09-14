class TsTaskDao {
    [string]$taskName
    [string]$taskPath
    [xml]$xml

    TsTaskDao($taskName, $taskPath) {
        $this.taskName = $taskName
        $this.taskPath = $taskPath
 
        $existFlg = (Get-ScheduledTask -TaskPath $taskPath | Where-Object TaskName -eq $taskName) -ne $null

        if (-not $existFlg) {
            $action = New-ScheduledTaskAction -Execute "%ProgramFiles%\PowerShell\7\pwsh.exe" -Argument "-ExecutionPolicy Bypass <Scripts>"
            Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action
        }        
        $this.xml = [xml](Export-ScheduledTask -TaskName $this.taskName -TaskPath $this.taskPath)       

        if (-not $existFlg) {
            Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false
        }
    }
    TsTaskDao($taskName, $taskPath, $scripts) {
        $this.taskName = $taskName
        $this.taskPath = $taskPath

        $action = New-ScheduledTaskAction -Execute "%ProgramFiles%\PowerShell\7\pwsh.exe" -Argument "-ExecutionPolicy Bypass $scripts"
        Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Force
        $this.xml = [xml](Export-ScheduledTask -TaskName $this.taskName -TaskPath $this.taskPath)       
        Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false
    }
    RemoveAllTrigger() {
        $this.xml.SelectSingleNode("//*[local-name()='Triggers']").RemoveAll()
    }
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
}
