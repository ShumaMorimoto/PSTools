class OTCalDAO {
    static [object] $syukujitsu = $null
    static [void] loadSyukujitsu() {
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
    static [object] getSyukujitsu([datetime]$st, [datetime]$ed) {
        return [OTCalDAO]::syukujitsu | Where-Object { ($st -lt (Get-Date($_."国民の祝日・休日月日"))) -and ((Get-Date($_."国民の祝日・休日月日")) -lt $ed) }
    }
    static [object] getSyukujitsu([Term]$term) {
        return [OTCalDAO]::getSyukujitsu($term.start, $term.end) 
    }
    static [object] getSyukujitsu([string]$st, [string]$ed) {
        return [OTCalDAO]::getSyukujitsu((Get-Date($st)), (Get-Date($ed)))
    }
    static [object] getSyukujitsu([datetime]$st) {
        return [OTCalDAO]::getSyukujitsu($st, $st.AddYears(1))
    }
}
