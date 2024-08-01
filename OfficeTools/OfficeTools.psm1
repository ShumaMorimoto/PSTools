function DMSort {
    param ([System.xml.XmlElement]$table, [ScriptBlock] $orderfunc) 
    $table.tbody.tr | Sort-Object -Property @{Exp = { &$orderfunc $_ } } | % { $table.tbody.appendChild($_) } | Out-Null
}
function DMSearch {
    param ([System.Xml.XmlElement]$table, [Object]$data, [ScriptBlock] $compfunc) 
    return $table.tbody.tr | Where-Object { &$compfunc $_ $data }
}
function DMAddrow {
    param ([System.xml.XmlElement]$table, [Object] $data) 
    $tr=$table.tbody.AppendChild($table.ownerdocument.CreateElement("tr")) 
    $header | %{$tr.AppendChild($table.ownerdocument.CreateElement("td")).InnerText = $data[$_]}
    return [System.Xml.XmlElement]$tr
}
function DMAppendrow {
    param ([System.xml.XmlElement]$table, [Object] $data, [ScriptBlock] $compfunc)
    $tr = DMSearch $table $data $compfunc
    if($tr -eq $null){
        $tr=DMAddrow $table $data 
    }
    return [System.Xml.XmlElement]$tr
}
function DMCreateTable {
    param ([xml]$doc, [Object] $tdata) 

    $table = $doc.CreateElement("table")
    $tbody = $table.AppendChild($doc.CreateElement("tbody"))
    $tr = $tbody.AppendChild($doc.CreateElement("tr")) 
    
    $tdata.header | %{$tr.AppendChild($doc.CreateElement("th")).InnerText = $_}
    $tdata.data | %{DMAddrow $table $_|Out-Null}

    return [System.Xml.XmlElement]$table
}
function DMConvertTable{
    param ([System.xml.XmlElement]$table) 
    $header = [array]$table.tbody.tr[0].th 
    $data = @();    
    foreach($tr in $table.tbody.tr) {
        if($tr.td.length -gt 0){
          $dt = [array] $tr.td
          $dt2 = @{}
          for($i = 0; $i -lt $header.length; $i++){
            $dt2 += @{$header[$i]=$dt[$i]}
          }
          $data += $dt2
        }
    }      
    return @{header=$header;data=$data}
}
function OLfilter {
    param ([Object]$items, [Object]$keywords) 

    $filter = "@SQL=urn:schemas:httpmail:subject LIKE '" + [string]::Join("' OR urn:schemas:httpmail:subject LIKE '", $keyword) + "'" 
    return $items.Restrict($filter)
}
function OLformatDT ([Object]$dt){
    if($dt -is [datetime]){$dt = $dt.toString("yyyy/M/d hh:mm")} 
    return $dt
}
class OutlookDAO {
    [object] $outlook
    [object] $namespace
    [object] $folder

    OutlookDAO([string]$receiver) {
        $this.initialize()
        $this.setFolder($receiver)
    }
    OutlookDAO() {
        $this.initialize()
        $this.setFolder()
    }
    [void] initialize() {
        $this.outlook = New-Object -ComObject Outlook.Application
        $this.namespace = $this.outlook.GetNamespace("MAPI")
    }
    [void] setFolder() {
        $this.folder = $this.namespace.GetDefaultFolder(9) 
    }
    [void] setFolder([string]$reciever) {
        $rec = $this.outlook.CreateRecipient($reciever)
        $this.folder = $this.namespace.GetSharedDefaultFolder($rec, 9) 
    }
    [object] getApos([string] $startDT, [string] $endDT) {
        $items = $this.folder.Items
        $items.IncludeRecurrences = $true       
        $items.Sort("[Start]")
        $filter = "[Start] < '$endDT' AND [End] > '$startDT'"
    
        return $items.Restrict($filter)
    }
    [object] getApos() {
        return $this.getApos(1)
    }
    [object] getApos([int]$term) {
        $date = Get-Date  
        return $this.getApos($date.toString("yyyy/M/d 00:00"), $date.adddays($term).toString("yyyy/M/d 00:00"))
    }
    [object] checkApos([object] $startDT, [object] $endDT) {
        $items = $this.folder.Items
        $items.IncludeRecurrences = $true       
        $items.Sort("[Start]")
        $startDT = OLformatDT($startDT)
        $endDT = OLformatDT($endDT)
        $filter = "[Start] = '$startDT' AND [End] = '$endDT'"
        return $items.Restrict($filter)
    }
    [object] createMail() {
        return $this.outlook.CreateItem(0)
    }
    [object] createApos([object]$startDT, [object]$endDT) {
        $item = $this.outlook.CreateItem(1) #olAppointmentItem
        $item.Start = OLFormatDT($startDT)
        $item.End = OLformatDT($endDT)
        return $item
    }
}