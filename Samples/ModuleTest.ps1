using module OfficeTools2

$tdata = @{
    header = @("開催日", "顧客名", "担当")
    data   = @(
        [pscustomobject]@{開催日 = "2024/7/1"; 顧客名 = "YMT"; 担当 = "俺" },
        [pscustomobject]@{開催日 = "2024/8/1"; 顧客名 = "RCVT”; 担当 = "彼" }
        [pscustomobject]@{開催日 = "2024/6/1"; 顧客名 = "YMT”; 担当 = "誰" }
        [pscustomobject]@{開催日 = "2024/4/1"; 顧客名 = "RCVT”; 担当 = "其" }
    )            
}
$compfunc = {
    param([System.Xml.XmlElement]$tr, [pscustomobject]$data)
    return (($tr.td[0] -eq $data.開催日 ) -and ($tr.td[1] -eq $data.顧客名))
}


#XML
$dom = New-Object OTDomDAO("<xml></xml>")
$o = $dom.CreateTable($tdata)
$o.AddRow(@{開催日 = "2024/7/1"; 顧客名 = "YMT"; 担当 = "俺" })
$o.toJSON()
$o.Search(@{開催日 = "2024/8/1"; 顧客名 = "RCVT”}, $compfunc)
$o.Sort({param($tr) return $tr.td[0] })
$o.element.OuterXml


#Excel
$o2 = New-Object OTExcelDAO("C:\Users\shuma\OneDrive\ドキュメント\テスト.xlsm", $true)
$o2.show()

$table = $o2.getTable("コピー先","A1:G1") 
$table.AddRow($tdata.data) | Out-Null
$table.toJSON()

$orderfunc2 = {
    param([Object]$row)
    $val1 = $row.Columns[4].Text
    $val2 = $row.Columns[5].Text
    return datenormalizer $val1 $val2
}
$table.Sort($orderfunc2)
$table.toObject().data | ogv

#PowerPoint
$o = New-Object OTPowerpointDAO("D:\tool\tmp\テスト.pptx")
$table = $o.GetTable()
ConvertTo-JSON -depth 3 $table | Set-Content -path "D:\tool\tmp\table.json"
$table.data |  ogv

#Outlook
$o = New-Object OTOutlookDAO
$table = $o.GetApoTable()
$table.toObject()
$citems = $table.GetApos()
$citems | %{$body += $_.Start.toString("M/d(ddd) hh:mm-") + $_.End.toString("hh:mm ") + $_.Subject + " @" + $_.Location+"`r`n"}

$mail = $o.CreateMail()
$mail.To = "shumamorimoto@gmail.com"
$mail.Subject = "自動メール"
$mail.body = [string]$body
$mail.Display()

$date = Get-Date
$apo = $table.CreateApo(@{Start=$date;End=$date.addHours(1)})
$apo.Subject = "自動登録"
$apo.Location = "Zoom"
$apo.body = [string]$body
$apo.Display()

$evnt = $table.CreateEvent((Get-Date))
$evnt.Subject = "終日イベント"
$evnt.body = [string]$body
$evnt.Display()

$select = ($table.toObject().data | ogv -PassThru)

$select | %{$item = $o.SearchItem($_.EntryID)
    $item.Body += "Zoom"
    $item.Location = "TOYOTA"
    $item.Display()
}
$folder = [OTOutlookDAO]::namespace.GetDefaultFolder(6) 
$m = New-Object OlMailTable($folder)
$m.toObject().data| ogv

