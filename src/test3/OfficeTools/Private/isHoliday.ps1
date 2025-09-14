function isHoliday([datetime]$date) {
    if ([OTCalDAO]::syukujitsu -eq $null) { [OTCalDAO]::loadSyukujitsu() }
    $holiday = ([OTCalDAO]::syukujitsu | Where-Object "国民の祝日・休日月日" -eq $date.ToString("yyyy/M/d"))."国民の祝日・休日名称"
    return $holiday
}
