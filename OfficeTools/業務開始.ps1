using module OfficeTools

$o = New-Object OutlookDAO

$citems = $o.getApos()

$citems | %{$body += $_.Start.toString("M/d(ddd) hh:mm-") + $_.End.toString("hh:mm ") + $_.Subject + " @" + $_.Location+"`r`n"}

$mail = $o.CreateMail()
$mail.To = "shumamorimoto@gmail.com"
$mail.Subject = "自動メール"
$mail.body = [string]$body
$mail.Display()

$date = Get-Date
$apo = $o.CreateApos($date,$date.addHours(1))
$apo.Subject = "自動登録"
$apo.Location = "Zoom"
$apo.body = [string]$body
$apo.Display()

$o.checkApos($date,$date.AddHours(1))


$citems = $o.getApos()

#$citem = $citems | Select-Object -Property Start,Subject,Location,Body,EntryID| Out-GridView -OutputMode Single

$date = @{label="日程";expression={$_.Start.toString("M/d(ddd)")}}
$term = @{label="時間";expression={$_.Start.toString("HH:mm - ")+$_.End.toString("HH:mm")}}

$citems | Where-Object {($_.Location -eq "") -and ($_.Body -notlike "Zoom")}


$select = ($citem = $citems | Select-Object $date,$term,Subject,Location,Body,EntryID| Out-GridView -PassThru)

$select | %{$item = $o.GetApo($_.EntryID)
    $item.Body += "Zoom"
    $item.Location = "TOYOTA"
    $item.Display()
}


$o = New-Object PPTableDAO("D:\tool\tmp\テスト.pptx")
$o.GetTable()
ConvertTo-JSON $o.table | Set-Content -path "D:\tool\tmp\table.json"
