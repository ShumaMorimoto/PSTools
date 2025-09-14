GetTasks() {
        $this.table = Get-ScheduledTask -TaskPath $this.taskPath | ForEach-Object { New-Object TsTaskDAO($_.TaskName, $this.taskPath) }
    }
