ReRegisterAll() {
        foreach ($task in $this.table) {
            Set-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath `
                -User ([OTConfig]::Settings.Credential.id) -Password ([OTConfig]::password)
        }
    }
