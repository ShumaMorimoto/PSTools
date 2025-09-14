Register ([TsTaskDAO]$task) {
        Register-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath -Xml $task.xml.OuterXml `
            -User ([OTConfig]::Settings.Credential.id) -Password ([OTConfig]::password) -Force  
    }
