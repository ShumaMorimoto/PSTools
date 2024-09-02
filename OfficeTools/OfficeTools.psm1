class AbstractTable {
    [string[]] $header = @()
    [pscustomobject[]] $data = @()

    [pscustomobject] toObject() {
        return [pscustomobject]@{header = $this.header; data = $this.data }
    }
    [object] toJSON() {
        return ConvertTo-JSON -depth 3 $this.toObject()
    }
    [object] Search([pscustomobject]$data, [ScriptBlock] $compfunc) {
        return $null
    }
    [void] Sort([ScriptBlock] $orderfunc) {
    }
    [object]AddRow([pscustomobject[]] $data) { 
        return $null
    }
    [object]SetHeader([string[]] $header) { 
        return $null
    }
}
class DomTable : AbstractTable {
    [System.Xml.XmlElement] $element

    DomTable([System.Xml.XmlElement]$table, [pscustomobject[]]$tdata) {
        $this.element = $table
        $this.SetHeader($tdata.header) | Out-Null
        $this.AddRow($tdata.data) | Out-Null
    }
    DomTable([System.Xml.XmlElement]$table) {
        $this.element = $table
        $this.header = $table.GetElementsByTagName("th") | ForEach-Object { $_.innerText }
    }
    [pscustomobject] toObject() {
        $this.data = @() 
        $this.element.tbody.tr | Where-Object { $_.td.length -gt 0 } | ForEach-Object {
            $dt = [array] $_.td
            $dt2 = [ordered]@{}
            for ($i = 0; $i -lt $this.header.length; $i++) {
                $dt2 += @{$this.header[$i] = $dt[$i] }
            }
            $this.data += [pscustomobject]$dt2
        }
        return [pscustomobject]@{header = $this.header; data = $this.data }
    }
    [object] Search([pscustomobject]$data, [ScriptBlock] $compfunc) {
        return $this.element.tbody.tr | Where-Object { $_.td.length -gt 0 } | Where-Object { &$compfunc $_ $data }
    }
    [void] Sort([ScriptBlock] $orderfunc) {
        $this.element.tbody.tr | Where-Object { $_.td.length -gt 0 } | Sort-Object -Property @{Exp = { &$orderfunc $_ } } | ForEach-Object { $this.element.tbody.appendChild($_) } | Out-Null
    }
    [System.xml.XmlElement]AddRow([pscustomobject[]] $data) { 
        foreach ($d in $data) {
            $tr = $this.element.tbody.AppendChild($this.element.OwnerDocument.CreateElement("tr")) 
            $this.header | ForEach-Object { $tr.AppendChild($this.element.OwnerDocument.CreateElement("td")).InnerText = $d.$_ }
        }
        return $this.element
    }
    [System.xml.XmlElement]SetHeader([string[]] $header) { 
        $tbody = $this.element.AppendChild($this.element.OwnerDocument.CreateElement("tbody"))
        $tr = $tbody.AppendChild($this.element.OwnerDocument.CreateElement("tr")) 
        $header | ForEach-Object {
            $tr.AppendChild($this.element.OwnerDocument.CreateElement("th")).InnerText = $_
        }
        $this.header = $header
        return [System.Xml.XmlElement]$tr
    }
}
Class OTDomDAO :System.Xml.XmlDocument {
    [DomTable[]] $tables = @()
    
    OTDomDAO() {
    }
    OTDomDAO([string]$xml) {
        $this.LoadXML($xml)  
    }
    [void]LoadXML($xml) {
        [System.Xml.XmlDocument]$this.LoadXML($xml)
        $this.GetTables() | Out-Null
    }
    [DomTable]CreateTable([pscustomobject] $tdata) {
        return $this.CreateTable($tdata, $this.DocumentElement)
    }
    [DomTable]CreateTable([pscustomobject] $tdata, [System.Xml.XmlElement] $parent) {
        $element = $this.CreateElement("table")
        $parent.AppendChild($element)
        $table = $this.AppendTable($element)
        $table.SetHeader($tdata.header) | Out-Null
        $table.AddRow($tdata.data) | Out-Null
        return $table
    }
    [DomTable]AppendTable([System.Xml.XmlElement] $element) {
        $table = New-Object DomTable($element)
        $this.tables += $table
        return $table
    }
    [DomTable]AppendTable([System.Xml.XmlElement] $element, [System.Xml.XmlElement] $parent) {
        $parent.AppendChild($element)
        return $this.AppendTable($element)
    }
    [object] GetTables() {
        $this.getElementsByTagName("table") | ForEach-Object { $this.AppendTable($_) | Out-Null }
        return $this.tables
    }
}

class ExTable :AbstractTable {
    [object] $range
    [hashtable] $eheader = [ordered]@{}

    ExTable([object]$range) {
        $this.range = $range
        $this.eheader = $this.GetHeader()
    }
    [object] GetHeader() {
        $this.eheader = [ordered]@{}
        if ($this.range.rows.count -eq 1) {
            $this.range | where-object Text -ne "" | ForEach-Object { $this.eheader.Add($_.Text, $_) }
        }  
        else {
            $this.range.rows(1).Columns | Where-Object Text -ne "" | ForEach-Object {
                if ($_.MergeArea.Columns.Count -gt 1) {
                    $this.eheader.Add($_.Text, $_.Offset(1, 0).Resize(1, $_.MergeArea.Count))
                }
                else {    
                    $this.eheader.Add($_.Text, $_) 
                }
            }
        }
        return $this.eheader  
    }
    [object] AddRow([pscustomobject[]]$data) {
        $rrange = $this.range.End(-4121).Offset(1, 0)
        foreach ($record in $data) {
            $this.eheader.keys | ForEach-Object {
                $cell = $this.eheader[$_]
                if ($cell.MergeArea.Columns.Count -eq 1) {
                    $rrange.Resize(1, 1).Offset(0, $cell.Column - $rrange.Column) = $record.$_
                }
                elseif ($cell.MergeCells) {
                    if ($record.$_.Count -gt 0) {
                        $rrange.Offset(0, $cell.Column - $rrange.Column).Resize(1, $record.$_.Count) = $record.$_
                    }
                }
            }
            $rrange = $rrange.Offset(1, 0)
        }
        return $this.range
    }
    [PSCustomObject] GetRow([object]$range) {
        $data = [ordered]@{}
        $this.eheader.keys | ForEach-Object {
            $value = ""
            $cell = $this.eheader[$_]

            if ($cell.MergeArea.Columns.Count -eq 1) {
                $value = $range.Resize(1, 1).Offset(0, $cell.Column - $range.Column).Text
            }
            elseif ($cell.MergeCells) {
                $value = @()
                $range.Offset(0, $cell.Column - $range.Column).Resize(1, $cell.MergeArea.Count).Columns | ForEach-Object { if ($_.Text -ne "") { $value += $_.Text } }
            }
            else {
                $value = @{}
                $cell | ForEach-Object { 
                    $vcell = $range.Resize(1, 1).Offset(0, $_.Column - $range.Column)
                    if ($vcell.Text -ne "") { $value.Add($_.Text, $vcell.Text) } 
                }
            }
            $data.Add($_, $value)
        }
        return [pscustomobject]$data
    }
    [object] SearchRow([pscustomobject]$data, [ScriptBlock] $compfunc) {
        $rrange = $this.GetRange()
        return ($rrange.rows | Where-Object { &$compfunc $_ $data } )
    }
    [pscustomobject] toObject() {
        $rrange = $this.GetRange()
        $data = @()
        $rrange.rows | ForEach-Object { $data += $this.GetRow($_) }  
        $this.header = $this.eheader.keys | Sort-Object -Property @{Exp = { $this.header[$_].Column } } 
        $this.data = $data
        return [pscustomobject]@{header = $this.header; data = $this.data }
    }
    [object] GetRange() {
        $r = $this.range.Offset($this.range.Rows.Count, 0)
        if ($r.Cells(1, 1) -eq "") { $r = $null }
        else {
            $r = $r.Resize($r.End(-4121).row - $r.row + 1)
        }
        return $r
    }
    [boolean] Sort([ScriptBlock] $orderfunc) {
        $rrange = $this.GetRange()
        $keycol = $this.range.WorkSheet.Columns.Count
        $rrange = $rrange.Resize($rrange.Rows.Count, $keycol)
        $key = $rrange.columns[$keycol]
    
        $rrange.rows | ForEach-Object { $_.Columns[$keycol] = &$orderfunc $_ }
        # $key.ClearContents()
        return $rrange.Sort($key, 1)
    }   
}
class OTExcelDAO {
    static [object] $excel
    [object] $book
    [hashtable] $tables = @{}

    [void]Show() {
        if (-not [OTExcelDAO]::excel.Visible) {
            [OTExcelDAO]::excel.Visible = $true
            if ($this.book.ReadOnly) { $this.book.ChangeFileAccess(2) }
        } 
    }
    [void]Close() {
        $this.book.close()
    }
    OTExcelDAO([string]$path, [boolean]$readOnly = $true) {
        $this.initialize($path, $readOnly)
    }
    [void] initialize([string]$path, [boolean]$readOnly) {
        $path -match "[^\\]+\.xls[m]*"
        $bookname = $Matches[0]
        try {
            if ($null -ne [OTExcelDAO]::excel) {
                $this.book = [OTExcelDAO]::excel.Workbooks | Where-Object Name -eq $bookname
                if ($null -eq $this.book ) {
                    $this.book = [OTExcelDAO]::excel.Workbooks.Open($path, 0, $readOnly)
                }
            }
            else {
                throw "New Object"
            }
        }
        catch {
            Get-Process | where-object name -eq "Excel" | Stop-Process
            [OTExcelDAO]::excel = New-Object -ComObject Excel.Application
            $this.book = [OTExcelDAO]::excel.Workbooks.Open($path, 0, $readOnly)  
        }
    }

    [Extable] GetTable([string]$sheetname, [string]$address) {
        $sheet = $this.book.Worksheets($sheetname)
        $range = $sheet.Range($address)
        $table = New-Object ExTable($range)
        $this.tables.Add($sheetname, $table)
        return $table
    }
}
class OlApoTable:AbstractTable {
    [object]$folder
    [object]$items

    static $selectheader = @(
        @{label = "日付"; expression = { $_.Start.toString("M/d(ddd)") } },
        @{label = "時間"; expression = { $_.Start.toString("HH:mm-") + $_.End.toString("HH:mm") } },
        "Subject", "Location", "Body", "EntryID"
    )

    OlApoTable([object]$folder) {
        $this.folder = $folder
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items.Sort("[Start]")
    }
    [pscustomobject] toObject() {
        return [OlApoTable]::toObject($this.items)
    }
    static [pscustomobject] toObject([object]$items) {
        return [pscustomobject]@{
            header = @("日付", "時間", "Subject", "Location", "Body", "EntryID")
            data   = $items | Select-Object ([OlApoTable]::selectheader) 
        }
    }
    [object] Search([pscustomobject]$data, [ScriptBlock] $compfunc) {
        return $this.items | Where-Object { &$compfunc $_ $data }
    }
    [object] SearchApos([object] $startDT, [object] $endDT) {
        $startDT = [OTOutlookDAO]::formatDT($startDT)
        $endDT = [OTOutlookDAO]::formatDT($endDT)
        $filter = "[Start] = '$startDT' AND [End] = '$endDT'"
        return $this.items.Restrict($filter)
    }
    [object] GetApos([string] $startDT, [string] $endDT) {
        $filter = "[Start] < '$endDT' AND [End] > '$startDT'"   
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items.Sort("[Start]")
        $this.items = $this.items.Restrict($filter)
        return $this.Items
    }
    [object] GetApos() {
        return $this.GetApos(1)
    }
    [object] GetApos([int]$term) {
        $date = Get-Date  
        return $this.GetApos($date.toString("yyyy/M/d 00:00"), $date.adddays($term).toString("yyyy/M/d 00:00"))
    }
    [void] Sort([ScriptBlock] $orderfunc) {
        $this.items.Sort("[Start]")
    }
    [object]CreateApo([pscustomobject] $data) { 
        $item = $this.items.Add()
        $item.Start = [OTOutlookDAO]::FormatDT($data."Start")
        $item.End = [OTOutlookDAO]::formatDT($data."End")
        return $item
    }
    [object]CreateEvent([datetime] $date) { 
        $item = $this.items.Add()
        $item.Start = $date.toString("yyy/M/d 00:00")
        $item.End = $date.addDays(1).toString("yyy/M/d 00:00")
        $item.AllDayEvent = $true
        return $item
    }
    [object]Restrict([Object]$keywords) { 
        $this.items = [OTOutlookDAO]::filterItems($this.items, $keywords)
        return $this.items
    }
}
class OlMailTable:AbstractTable {
    [object]$folder
    [object]$items
    
    static $selectheader = @(
        @{label = "受信日時"; expression = { $_.ReceivedTime } },
        @{label = "送信者"; expression = { $_.Sender.Address } },
        @{label = "宛先"; expression = { $_.To } },
        @{label = "CC"; expression = { $_.Cc } },
        "Subject", "Body", "EntryID"
    )   
    OlMailTable([object]$folder) {
        $this.folder = $folder
        $this.items = $this.folder.items
        $this.items.Sort("[ReceivedTime]")
    }
    [pscustomobject] toObject() {
        return [OlMailTable]::toObject($this.items)
    }
    static [pscustomobject] toObject([object]$items) {
        return [pscustomobject]@{
            header = @("受信日時", "送信者", "宛先", "CC", "Subject", "Body", "EntryID")
            data   = $items | Select-Object ([OlMailTable]::selectheader)
        }
    }
    [object] Search([pscustomobject]$data, [ScriptBlock] $compfunc) {
        return $this.items | Where-Object { &$compfunc $_ $data }
    }
    [object] GetMails([string] $startDT, [string] $endDT) {
        $filter = "[ReceivedTime] < '$endDT' AND [ReceivedTime] > '$startDT'"
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items = $this.folder.items.Restrict($filter)
        return $this.items
    }
    [object] GetMails() {
        return $this.GetMails(1)
    }
    [object] GetMails([int]$term) {
        $date = Get-Date
        return $this.GetMails($date.addDays(-$term).toString("yyyy/M/d 23:59"), $date.toString("yyyy/M/d 23:59"))
    }
    [void] Sort([ScriptBlock] $orderfunc) {
        $this.items.Sort("[ReceivedTime]")
    }
    [void] AddMail([object]$item) {
        $item | ForEach-Object { $_.Move($this.folder) }
    }
    [OlMailTable] GetMailTable([string]$path) {
        $subfolder = $this.folder
        $path -split "\\" | select-object -skip 2 | ForEach-Object { $subfolder = $subfolder.folders($_) }
        return New-Object OLMailTable($subfolder)
    }
    [object]Restrict([Object]$keywords) { 
        $this.items = [OTOutlookDAO]::filterItems($this.items, $keywords)
        return $this.items
    }
}
class OTOutlookDAO {
    static [object] $outlook
    static [object] $namespace

    OTOutlookDAO() {
        $this.initialize()
    }
    [void] initialize() {
        try {
            if ($null -ne [OTOutlookDAO]::outlook) {
                [OTOutlookDAO]::namespace = [OTOutlookDAO]::outlook.GetNamespace("MAPI")
            }
            else {
                throw "New Object"
            }
        }
        catch {
            [OTOutlookDAO]::outlook = New-Object -ComObject Outlook.Application
            [OTOutlookDAO]::namespace = [OTOutlookDAO]::outlook.GetNamespace("MAPI")
        }
    }
    [OlApoTable] GetApoTable([string]$receiver) {        
        $folder = switch ($receiver) {
            "" {
                [OTOutlookDAO]::namespace.GetDefaultFolder(9)
            }
            default {
                $rec = [OTOutlookDAO]::namespace.CreateRecipient($receiver)
                [OTOutlookDAO]::namespace.GetSharedDefaultFolder($rec, 9)           
            }
        } 
        return New-Object OlApoTable($folder)
    }
    [object] GetApoTable() {        
        return $this.GetApoTable($null)
    }
    [OlMailTable] GetMailTable() {
        return New-Object OLMailTable([OTOutlookDAO]::namespace.GetDefaultFolder(6))
    }
    [OlMailTable] GetMailTable([string]$path) {
        $folder = [OTOutlookDAO]::namespace
        $path -split "\\" | select-object -skip 2 | ForEach-Object { $folder = $folder.folders($_) }
        return New-Object OLMailTable($folder)
    }
    static [string] formatDT ([Object]$dt) {
        if ($dt -is [datetime]) { $dt = $dt.toString("yyyy/M/d HH:mm") } 
        return $dt
    }
    static [object] filterItems([Object]$items, [Object]$keywords) { 
        $filter = "@SQL=urn:schemas:httpmail:subject LIKE '" + [string]::Join("' OR urn:schemas:httpmail:subject LIKE '", $keywords) + "'" 
        return $items.Restrict($filter)
    }
    [object] SearchItem([object] $id) {
        return [OTOutlookDAO]::namespace.GetItemFromID($id)
    }
    [object] createMail() {
        return [OTOutlookDAO]::outlook.CreateItem(0)
    }
}
class PpTable:AbstractTable {

    PpTable([object]$presen) {
        $this.GetTable($presen) | Out-Null
    }
    [pscustomobject] GetTable($presen) {
        $tables = $presen.slides | ForEach-Object { ($_.shapes | Where-Object { $null -ne $_.table } | ForEach-Object { $_.table }) }
        $data = @()
        $tables | ForEach-Object { 
            $_.rows | ForEach-Object {
                $r = @() 
                $_.Cells | ForEach-Object { $r += $_.Shape.TextFrame.TextRange.Text }
                $data += $null
                $data[$data.length - 1] = $r
            }
        }
        $this.header = $data[0]
        $this.data = @()
        $data | Where-Object { $_[0] -ne $data[0][0] } | ForEach-Object {
            $i = 0; $rc = [ordered]@{}
            foreach ($key in $this.header) {
                $rc.add($key, $_[$i])
                $i++
            }
            $this.data += [pscustomobject]$rc
        }
        return [pscustomobject]@{header = $this.header; data = $this.data }
    }
    [pscustomobject] toObject() {
        return [pscustomobject]@{header = $this.header; data = $this.data }
    }
}
class OTPowerpointDAO {
    static [object] $powerpoint
    [object] $presen

    OTPowerpointDAO([string]$path) {
        [OTPowerpointDAO]::initialize()
        $this.presen = [OTPowerpointDAO]::powerpoint.Presentations.Open($path)
    }
    static [void] initialize() {
        if ($null -eq [OTPowerpointDAO]::powerpoint) {
            [OTPowerpointDAO]::powerpoint = New-Object -ComObject PowerPoint.Application
        }
    }
    [PpTable] GetTable() {
        return New-Object PpTable($this.presen)
    }
}
class ConfluDAO : OTDomDAO {
    static [string] $token = "MTAwNjk4NTA1MTcwOltz9manllOlRKkh3oAyY/xyX/z/"
    static [object] $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json; charset=UTF-8"
    }
    static [string] $dtd = @"
<!DOCTYPE page[
<!ENTITY nbsp "&#160;">
<!ATTLIST page xmlns:ci CDATA #FIXED "ci">
<!ATTLIST page xmlns:li CDATA #FIXED "li">
<!ATTLIST page xmlns:ac CDATA #FIXED "ac">
<!ATTLIST page xmlns:ri CDATA #FIXED "ri">
]>
"@
    [string] $page
    [int] $vernum
    [string] $title
    [xml] $doc
    [string] $base_url
    [string] $page_id

    ConfluDAO([string]$base_url, [string] $page_id) {
        [ConfluDAO]::getPAT() | Out-Null
        $this.Load($base_url, $page_id)
    }
    ConfluDAO() {
        [ConfluDAO]::getPAT()| Out-Null
    }
    [boolean]Load([string]$base_url, [string]$page_id) {
        $this.base_url = $base_url
        $this.page_id = $page_id
        $url = $this.base_url + $this.page_id + "?expand=body.storage,version"

        $response = Invoke-WebRequest -Uri $url -Method "GET" -Headers [ConfluDAO]::headers
        $content = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($response.Content))
        $json = ConvertFrom-JSON $content
        $this.page = $json.body.storage.value
        $this.vernum = $json.version.number
        $this.title = $json.title
                
        $this.LoadXml([ConfluDAO]::toXML($this.page))           
        return $true
    }
    [Object] Save() {
        $url = $this.base_url + $this.page_id

        $payload = @{
            title   = $this.title
            type    = "page"
            version = @{
                number = $this.vernum + 1
            }
            body    = @{
                storage = @{
                    representation = "storage"
                    value          = $this.page.innerXML
                }
            }
        }
        $json = ConvertTo-JSON -Compress $payload
        $response = Invoke-RestMethod -Uri $url -Body $json -Method "PUT" -Headers [ConfluDAO]::headers -ErrorVariable RespErr
        $this.vernum ++
        
        return $payload
    }
    static [string] toXML($value) {
        return([ConfluDAO]::dtd + "<page>$value</page>")
    }
    static [string] getPAT() {
        $file = "$PSScriptRoot\Conflu.settings.json"
        $settings = @{}
         if (Test-Path $file) {
            $settings = Get-Content $file | ConvertFrom-JSON 
            [ConfluDAO]::token = $settings.rawToken
            [ConfluDAO]::headers = @{
                "Authorization" = "Bearer " + [ConfluDAO]::token
                "Content-Type"  = "application/json; charset=UTF-8"
            }
   
            if ($settings.expiringAt -lt (Get-Date).AddDays(20)) {
                $baseUrl = "https://sd10.aslead.cloud/wiki/rest/pat/latest/tokens"
                $body = @{
                    name               = "myToken"
                    expirationDuration = 90
                }
                $json = ConvertTo-JSON -Compress $body
                $settings = Invoke-RestMethod -Uri $baseurl -Body $json -Method "POST" -Headers ([ConfluDAO]::headers)
                ConvertTo-JSON $settings | Set-Content $file
                [ConfluDAO]::token = $settings.rawToken
                [ConfluDAO]::headers = @{
                    "Authorization" = "Bearer " + [ConfluDAO]::token
                    "Content-Type"  = "application/json; charset=UTF-8"
                }
            }
        else {
        }
        }
        return [ConfluDAO]::token
    }
    static [void] setPAT([string]$PAT) {
        $file = "$PSScriptRoot\Conflu.settings.json"
        $settings = @{"rawToken" = $PAT }
        ConvertTo-JSON $settings | Set-Content $file
    }
} 
function getCred() {
    $file = "$PSScriptRoot\OfficeTools.settings.json"
    $settings = @{}
    if (!(Test-Path $file -NewerThan (Get-Date).addMonths(-6))) {
        $cred = Get-Credential
        $settings.add("id", $cred.UserName)
        $settings.add("password", (ConvertFrom-SecureString -SecureString $cred.Password))
        ConvertTo-JSON $settings | Set-Content $file
    }
    else {
        $settings = Get-Content $file | ConvertFrom-JSON 
    }
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $settings.password))
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $settings.password = $password
    return $settings
}
function datenormalizer {
    param([string]$val1, [string]$val2)
    
    switch -Regex ($val1) {       
        '(2\d/\d+/\d+)' {
            $order = [DateTime]::ParseExact($Matches[1], "yy/M/d", $null).toString("yyMMdd")
            if ($val2 -match "(\d+):(\d+)") {
                $order += $Matches[1].PadLeft(2, "0") + $Matches[2].PadLeft(2, "0")
            }
            else {
                $order += "9999"
            }
            break
        }
        '(2\d/\d+)/*([上中下末])' {
            $date = [DateTime]::ParseExact($Matches[1], "yy/M", $null)
            switch ($Matches[2]) {
                "上" { $order = $date.ToString("yyMM") + "109999" }
                "中" { $order = $date.ToString("yyMM") + "209999" }
                "下" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
                "末" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
            }
            break
        }
        '(\d+)月' {
            $order = (Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1].PadLeft(2, "0") + "019999"
            break
        }
        '(\d+)/*([上中下末])' {
            $date = [DateTime]::ParseExact((Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1], "yyM", $null)
            switch ($Matches[2]) {
                "上" { $order = $date.ToString("yyMM") + "109999" }
                "中" { $order = $date.ToString("yyMM") + "209999" }
                "下" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
                "末" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
            }
            break
        }
        '(2\d/\d+)' {
            $order = [DateTime]::ParseExact($Matches[1], "yy/M", $null).ToString("yyMM019999")
            break
        }
        '(\d+)/(\d+)[週-]*' {
            $order = (Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1].PadLeft(2, "0") + $Matches[2].Padleft(2, "0") 
            if ($val2 -match "(\d+):(\d+)") {
                $order += $Matches[1].PadLeft(2, "0") + $Matches[2].PadLeft(2, "0")
            }
            else {
                $order += "9999"
            }
            break
        }
        default { $order = "9999999999" }
    }
    return [string]$order
}
