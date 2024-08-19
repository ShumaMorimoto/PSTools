using module ConfluTools

$orderTR = {
    param([Object]$tr)
    return $tr.cells(0).innerHTML
}
$orderTR2 = {
    param([Object]$tr)
    return $tr.cells(1).innerHTML
}
$comp = {
    param([Object]$tr,$data)
    $date = $tr.cells[0].innerHTML
    $client = $tr.cells[1].innerHTML
    return (($date -eq $data[0] ) -and ($client -eq $data[1]))
}

$token = "ATATT3xFfGF0-DE_7AWjU81CaeXyz4HZghwPc5bdjtb7gXYyA2UDZHQOEEWLLS4zgtQwqsedLgzyTNMZzFwD1pbhjKTF48hRwnAfo6l2jysvkGKZCzqPkl9Ktavu0eub-mxbRK1__Ped5aT5gYmQmg2IdhDRBuhOv0w2LIBNTxPm4q0du3GIcnA=5E67F475"
$o = New-Object ConfluDAO("https://smorimoto.atlassian.net/wiki/rest/api/content/", "131074")
$o.Save()

$doc = $o.doc()
$table = $doc.createElement("table")
$doc.body.appendChild($table)　| Out-Null

$thead = $doc.createElement("thead")
$table.appendChild($thead) | Out-Null
$headrow = $doc.createElement("tr")
$thead.appendChild($headrow) | Out-Null

("開催日","顧客名") | %{$th = $doc.createElement("th");$th.innerHTML = $_; $headrow.appendChild($th)|Out-Null}

$tr = $table.insertRow(-1)
("20240808","YMT") | %{$tr.insertCell(-1).innerHTML = $_}

$tr = $table.insertRow(-1)
("20240701","RCV") | %{$tr.insertCell(-1).innerHTML = $_}

$tr = $table.insertRow(-1)
("20241001","RCV") | %{$tr.insertCell(-1).innerHTML = $_}

$doc.body.innerHTML

DMSort $table.tBodies(0) $orderTR

$tr = DMSearch $table.tbodies(0) "20241011","RCV" $comp
if ($tr -ne $null){
   $tr.innerHTML
} else {
  "NO Match"
}

function ConvertTH([object]$headrow){
   $header = @()
   $headrow.getElementsByTagName("th") | % {$header+=$_.innerHTML}
   return [array]$header
}
function ConvertTR([object]$tr, [array]$header){
    $data =@{}; $i=0
    $tr.Cells | % {$data.Add($header[$i],$_.innerHTML);$i++}
    return $data
 }

 $data = ConvertTR $tr $header

 
