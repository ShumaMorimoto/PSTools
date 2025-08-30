using module OfficeTools


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
    param([pscustomobject]$data)
    return (($data.開催日時 -eq "2024/1/1"))
}

#Excel
$o2 = New-Object OTExcelDAO("C:\Users\shuma\OneDrive\ドキュメント\テスト.xlsm", $true)
$table = $o2.getTable(1, "A1:G2") 

$table.GetHeader()

$data = $table.getData(3, $table.oHeader)
$table.AddRows($data)

$orderfunc2 = {
    param([Object]$row)
    return datenormalizer $row.開催日時 $row.担当
}
$table.Sort($orderfunc2)

$o2.show()
$table.AddRows($tdata.data)

$table.SearchRows({ $_.開催日時 -eq $date })
