class OTTaskSchedulerDAO {
    [string]$taskPath = "\マイタスク\"
    [TsTaskDAO[]]$table

    OtTaskSchedulerDAO($taskPath) {
        $this.taskPath = $taskPath
        $this.GetTasks()
    }
    OtTaskSchedulerDAO() {
        $this.GetTasks()
    }
    Register ([TsTaskDAO]$task) {
        Register-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath -Xml $task.xml.OuterXml `
            -User ([OTConfig]::Settings.Credential.id) -Password ([OTConfig]::password) -Force  
    }
    SetTrigger([TsTaskDAO]$task, [ciminstance]$trigger) {
        Set-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath -Trigger $trigger  `
            -User ([OTConfig]::Settings.Credential.id) -Password ([OTConfig]::password)  
    }
    GetTasks() {
        $this.table = Get-ScheduledTask -TaskPath $this.taskPath | ForEach-Object { New-Object TsTaskDAO($_.TaskName, $this.taskPath) }
    }
    ReRegisterAll() {
        foreach ($task in $this.table) {
            Set-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath `
                -User ([OTConfig]::Settings.Credential.id) -Password ([OTConfig]::password)
        }
    }
}
