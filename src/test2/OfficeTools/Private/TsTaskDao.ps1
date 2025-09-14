TsTaskDao($taskName, $taskPath, $scripts) {
        $this.taskName = $taskName
        $this.taskPath = $taskPath

        $action = New-ScheduledTaskAction -Execute "%ProgramFiles%\PowerShell\7\pwsh.exe" -Argument "-ExecutionPolicy Bypass $scripts"
        Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Force
        $this.xml = [xml](Export-ScheduledTask -TaskName $this.taskName -TaskPath $this.taskPath)       
        Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false
    }
