# タスクスケジュール用のXML定義を作成

$tri = [xml]@"
<Triggers>
<CalendarTrigger>
  <StartBoundary>2025-04-18T09:00:00</StartBoundary>
  <Enabled>true</Enabled>
  <ScheduleByMonth>
    <DaysOfMonth>
      <Day>1</Day> <!-- 毎月1日に実行 -->
    </DaysOfMonth>
    <Months>
      <January />
      <February />
      <March />
      <April />
      <May />
      <June />
      <July />
      <August />
      <September />
      <October />
      <November />
      <December />
    </Months>
  </ScheduleByMonth>
</CalendarTrigger>
</Triggers>
"@

# タスクを登録
#schtasks /Create /TN "MonthlyTask" /XML $taskXmlPath /F
#Register-ScheduledTask -Xml $taskXml -TaskName "FromXML"  -TaskPath "\マイタスク\"

$taskName = "FromXML"
$taskPath = "\マイタスク\"

#$xml = [xml](schtasks /Query /TN "$taskPath$taskName" /XML)
$xml = [xml](Export-ScheduledTask "$taskPath$taskName")


$triggers = $xml.Task.Triggers
$triggers.RemoveAll()

# 時間トリガーを追加
$trigger = $xml.CreateElement("CalendarTrigger", $xml.DocumentElement.NamespaceURI)
$triggers.AppendChild($trigger)

# トリガーの開始日時を設定
$startBoundary = $xml.CreateElement("StartBoundary", $xml.DocumentElement.NamespaceURI)
$startBoundary.InnerText = "2025-04-21T08:00:00"
$trigger.AppendChild($startBoundary)

# 繰り返し設定を追加
$schedule = $xml.CreateElement("ScheduleByMonth", $xml.DocumentElement.NamespaceURI)
$trigger.AppendChild($schedule)

$interval = $xml.CreateElement("DaysOfMonth", $xml.DocumentElement.NamespaceURI)
$schedule.AppendChild($interval)
(1..10) | ForEach-Object {
  $day = $xml.CreateElement("Day", $xml.DocumentElement.NamespaceURI)
  $day.InnerText = $_
  $interval.AppendChild($day)
}
$months = $xml.CreateElement("Months", $xml.DocumentElement.NamespaceURI)
$schedule.AppendChild($months)
("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December") | ForEach-Object {
  $month = $xml.CreateElement($_, $xml.DocumentElement.NamespaceURI)
  $months.AppendChild($month)
}
$triggers.AppendChild($trigger)


Register-ScheduledTask -Xml $xml.OuterXML -TaskName "FromXML"  -TaskPath "\マイタスク\"


$action = New-ScheduledTaskAction -Execute "notepad.exe"

$xml = [xml](Export-ScheduledTask "test")


class OTTaskSchedulerDAO {

  OTTaskSchedulerDAO() {
  }
  [object] CreateTask() {
    return [OTOutlookDAO]::outlook.CreateItem(0)
  }
}

class OTTaskDAO {
  [xml] $taskXml
  [string] $taskName
  [string] $taskPath
  [object] $action

  OTTaskDAO($taskName, $taskPath, $exec) {
    $this.taskName = $taskName
    $this.taskPath = $taskPath
    $this.action = New-ScheduledTaskAction -Execute $exec

    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $this.action
    $this.taskXml = [xml](Export-ScheduledTask "$taskPath$taskName")
  }
  AddMonthlyTrigger([string]$At, [object]$days) {   
    # 時間トリガーを追加
    $trigger = $this.taskXml.CreateElement("CalendarTrigger", $this.taskXml.DocumentElement.NamespaceURI)

    # トリガーの開始日時を設定
    $startBoundary = $this.taskXml.CreateElement("StartBoundary", $this.taskXml.DocumentElement.NamespaceURI)
    $startBoundary.InnerText = ([datetime]$At).ToString("yyyy-MM-ddTHH:mm:ss")
    $trigger.AppendChild($startBoundary)

    # 繰り返し設定を追加
    $schedule = $this.taskXml.CreateElement("ScheduleByMonth", $this.taskXml.DocumentElement.NamespaceURI)
    $trigger.AppendChild($schedule)

    $interval = $this.taskXml.CreateElement("DaysOfMonth", $this.taskXml.DocumentElement.NamespaceURI)
    $schedule.AppendChild($interval)

    $days | ForEach-Object {
      $day = $this.taskXml.CreateElement("Day", $xml.DocumentElement.NamespaceURI)
      $day.InnerText = $_
      $interval.AppendChild($day)
    }
    $months = $this.taskXml.CreateElement("Months", $this.taskXml.DocumentElement.NamespaceURI)
    $schedule.AppendChild($months)
    ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December") | ForEach-Object {
      $month = $this.taskXml.CreateElement($_, $this.taskXml.DocumentElement.NamespaceURI)
      $months.AppendChild($month)
    }
    $this.taskXml.Task.Triggers.AppendChild($trigger)
  }
}



