loadSyukujitsu() {
        if (!(Test-Path "$PSScriptRoot\data\syukujitsu.csv" -NewerThan (Get-Date).addMonths(-6))) {
            $url = 'https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv'
            Invoke-WebRequest -URI $url -OutFile "$PSScriptRoot\data\syukujitsu.csv"
        } 
        if ((Get-Host).Version.Major -eq 7) {
            [OTCalDAO]::syukujitsu = Import-Csv "$PSScriptRoot\data\syukujitsu.csv" -Encoding ANSI
        }
        else {
            [OTCalDAO]::syukujitsu = Import-Csv "$PSScriptRoot\data\syukujitsu.csv" -Encoding Default 
        }
    }
