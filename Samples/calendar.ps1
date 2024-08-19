Invoke-WebRequest `
-URI 'https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv' `
-OutFile syukujitsu.csv
$syukujitsu = Import-Csv .\syukujitsu.csv -Encoding ansi

isHoliday(Get-Date)

$date = Get-Date

for($i = 0 ; $i -lt 50 ; $i++){
    $date.adddays($i);
    isHoliday($date.adddays($i))
}

function isHoliday([datetime]$date){
    $holiday = ($syukujitsu | Where-Object "国民の祝日・休日月日" -Match $date.ToString("yyyy/M/d"))."国民の祝日・休日名称"
    return $holiday
}