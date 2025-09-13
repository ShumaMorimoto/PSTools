$this.header = $table.GetElementsByTagName("th") | ForEach-Object { $_.innerText }

$tables = $presen.slides | ForEach-Object { ($_.shapes | Where-Object { $null -ne $_.table } | ForEach-Object { $_.table }) }

$this.table = Get-ScheduledTask -TaskPath $this.taskPath | ForEach-Object { New-Object TsTaskDAO($_.TaskName, $this.taskPath) }

$this.posts = $response.order | ForEach-Object { $response.posts.$_ }

$data = , (@($this.oHeader | ForEach-Object { $row.$_ }))

$sheetId = ($this.sheets.properties | Where-Object { $_.title -eq $sheetName }).sheetID

$diff = switch ($_base.Month) { { (4 -le $_) -and ($_ -le 9) } { 4 }; default { 10 } }

$diff = switch ($_base.Month) { { 4 -le $_ } { 4 }; default { -8 } }

$diff = switch ($this.base.Month) { { (4 -le $_) -and ($_ -le 9) } { 4 }; default { 10 } }

$AddWorkDays = {
    param([int]$days)
    $idx = switch ($days -gt 0) { $true { 1 }; $false { -1 } }
    $d2 = Get-Date($this)
    while ($days -ne 0) {
        $d2 = $d2.AddDays($idx)
        while (-not $d2.isWorkDay) {
            $d2 = $d2.AddDays($idx)
        }
        $days -= $idx
    }
    return $d2
}

$isWorkDay = {
    return ((0, 6) -notcontains $this.DayOfWeek.value__) -and (-not $this.isHoliday) 
}

$Holiday = {
    if ([OTCalDAO]::syukujitsu -eq $null) { [OTCalDAO]::loadSyukujitsu() }
    $datestring = $this.ToString("yyyy/M/d")
    $holiday = ([OTCalDAO]::syukujitsu | Where-Object "国民の祝日・休日月日" -eq $datestring)."国民の祝日・休日名称"
    return $holiday
}

$isHoliday = {
    return $this.Holiday -ne $null
}

Update-TypeData -TypeName System.DateTime -MemberType ScriptProperty -MemberName Holiday -Value $Holiday

Update-TypeData -TypeName System.DateTime -MemberType ScriptProperty -MemberName isHoliday -Value $isHoliday

Update-TypeData -TypeName System.DateTime -MemberType ScriptMethod -MemberName AddWorkDays -Value $AddWorkDays

Update-TypeData -TypeName System.DateTime -MemberType ScriptProperty -MemberName isWorkDay -Value $isWorkDay
