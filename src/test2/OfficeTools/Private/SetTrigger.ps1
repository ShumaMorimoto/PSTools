SetTrigger([TsTaskDAO]$task, [ciminstance]$trigger) {
        Set-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath -Trigger $trigger  `
            -User ([OTConfig]::Settings.Credential.id) -Password ([OTConfig]::password)  
    }
