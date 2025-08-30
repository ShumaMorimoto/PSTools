using module OfficeTools

$today = Get-Date

if (-not $todya.isHoliday) {
    Write-EventLog -LogName Application -Source "投信更新" `
        -EventId 1001 -EntryType Information `
        -Message "投信取得開始"
}



