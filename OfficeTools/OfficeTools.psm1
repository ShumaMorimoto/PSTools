#HtmlAgilityPackの設定
if (-not ("HtmlAgilityPack.HtmlDocument" -as [type])) {
    Add-Type -Path "$PSScriptRoot\HtmlAgilityPack.dll"
}

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
class ExTable2 :AbstractTable {
    [object] $range
    [hashtable] $eheader = [ordered]@{}

    ExTable2([object]$range) {
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

                $vcell = $range.Resize(1, 1).Offset(0, $cell.Column - $range.Column)
                if ($vcell.Hyperlinks.Count -gt 0) {
                    $value = $vcell.Hyperlinks[1].Address
                }
                else {
                    $value = $vcell.Text
                }
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

class ExTable :AbstractTable {
    [object] $sheet
    [object] $range
    [PSCustomObject] $oHeader = [ordered]@{}
    [PSCustomObject] $oRows = @()
        
    ExTable([object]$range) {
        $this.sheet = $range.WorkSheet
        $this.range = $range
        $this.oHeader = $this.GetHeader()
    }
    [object] GetHeader() {
        return $this.getItems($this.range.Row, $this.range.Column, $this.range.Columns.Count)
    }   
    [PSCustomObject] getItems($row, $col, $count) {
        $obj = [ordered]@{}
        while ($count -gt 0) {
            $cell = $this.sheet.Cells($row, $col)
            $text = $cell.Text
            if ($text -ne "") {
                $cols = $cell.MergeArea.Columns.Count
                if ($cols -eq 1) {
                    # $obj.Add($cell.Text, $col)
                    $obj[$cell.Text] = $col
                }
                else {
                    $obj2 = $this.getItems($row + 1, $col, $cols)
                    #$obj.Add($cell.Text, $obj2)
                    $obj[$cell.Text] = $obj2
                }
            }
            $count --; $col ++
        }
        return $obj
    }
    [PSCustomObject] GetRows([int[]]$rows) {
        $this.oRows = @()
        foreach ($row in $rows) {
            $this.oRows += ($this.getData($row, $this.oHeader) + @{"_row" = $row })
        }
        return $this.oRows
    }
    [PSCustomObject] GetRows() {
        [int]$start = $this.startRow()
        [int]$end = $this.lastRow()
        if ($start -gt $end) {
            return $null
        }
        return $this.GetRows(($start..$end))
    }
    [PSCustomObject]getData([int]$row, [PSCustomObject]$item) {
        $obj = [ordered]@{}
        foreach ($key in $item.Keys) {
            if ($item.$key -is [int]) {
                $cell = $this.sheet.Cells($row, $item.$key)
                if ($cell.Hyperlinks.Count -eq 0) {
                    $obj.Add($key, $cell.Text)
                }
                else {
                    $obj.Add($key, @{Text = $cell.Text; Address = $cell.HyperLinks[1].Address })
                }
            }
            else {
                $obj.Add($key, $this.getData($row, $item.$key))
            }
        }
        return $obj
    }
    [PSCustomObject] AddRows([PSCustomObject[]]$data) {
        $lastrow = $this.lastRow() + 1
        foreach ($record in $data) {
            $this.setData($lastrow, $this.oHeader, $record)
        }
        $this.oROws = $this.GetRows()
        return $this.oRows
    }
    [void]setData([int]$row, [PSCustomObject]$item, [PSCustomObject]$data) {
        if ($null -ne $data) {
            foreach ($key in $item.Keys) {
                if ($item.$key -is [int]) {
                    $this.sheet.Cells($row, $item.$key) = $data.$key
                }
                else {
                    $this.setData($row, $item.$key, $data.$key)
                }
            }
        }
    }
    [PSCustomObject] SearchRows([ScriptBlock] $compfunc) {
        return ($this.oRows | Where-Object { &$compfunc $_ } )
    }
    [PSCustomObject] toObject() {
        return [PSCustomObject]@{header = $this.oHeader; data = $this.oRows }
    }
    [int] startRow() {
        return $this.range.Row + $this.range.Rows.Count
    }  
    [int] lastRow() {
        $cell = $this.sheet.Cells($this.startRow(), $this.range.Column)
        $lastrow = switch ($cell.Text) {
            "" { $this.startRow() - 1 }
            default { $cell.End( - 4121).row }
        }
        return $lastrow
    }  
    [boolean] Sort([ScriptBlock] $orderfunc) {
        $keycol = $this.sheet.Columns.Count
        
        foreach ($data in $this.oRows) { $this.sheet.Cells($data._row, $keycol) = &$orderfunc $data }

        $cell1 = $this.sheet.Cells(($this.oRows._row | Select-Object -First 1), $this.range.Column)
        $cell2 = $this.sheet.Cells(($this.oRows._row | Select-Object -Last 1), $keycol)
        $drange = $this.sheet.Range($cell1, $cell2)
        $key = $drange.Columns[$keycol]
        # $key.ClearContents()
        return $drange.Sort($key, 1)
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
    [void]Save() {
        $this.book.Save()
    }
    [void]Close() {
        $this.book.Close()
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
    [Extable] GetTable([object]$parm, [string]$header) {
        $sheet = $this.book.Worksheets($parm)
        $range = $sheet.Range($header)
        $table = New-Object ExTable($range)
        $this.tables.Add($sheet.Name, $table)
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
    [object] GetUnreadMails([string] $startDT, [string] $endDT) {
        $filter = "[UnRead] =True AND [ReceivedTime] < '$endDT' AND [ReceivedTime] > '$startDT'"
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items = $this.folder.items.Restrict($filter)
        return $this.items
    }
    [object] GetUnreadMails() {
        return $this.GetUnreadMails(1)
    }
    [object] GetUnreadMails([int]$term) {
        $date = Get-Date
        return $this.GetUnreadMails($date.addDays(-$term).toString("yyyy/M/d 23:59"), $date.toString("yyyy/M/d 23:59"))
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
    [OlMailTable] GetUnsentMailTable() {
        return New-Object OLMailTable([OTOutlookDAO]::namespace.GetDefaultFolder(4))
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
    static [object] ResolveAddress([string]$name) {
        if (($name -eq "") -or $null -eq $name) {
            return $null
        }
        if ($name -match "(.{3})　(.{3})") {   
            $name = ($Matches[1] -replace "　", "") + " " + ($Matches[2] -replace "　", "")
        }
        $recip = [OTOutlookDAO]::namespace.CreateRecipient($name)
        $user = @{氏名 = $name }

        if ($recip.Resolve()) {     
            $user.氏名 = $recip.Name
            $user.メール = $recip.AddressEntry.GetExchangeUser().PrimarySmtpAddress

            if ($recip.Name -match "(.+　.+)\((\d+)\)(.+)$") {
                $user.氏名 = $Matches[1]
                $user.内線番号 = $Matches[2]
                $user.所属 = $Matches[3]
            }
        }       
        return $user
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
<!ENTITY lArr "&#8656;">
<!ENTITY uArr "&#8657;">
<!ENTITY rArr "&#8658;">
<!ENTITY dArr "&#8659;">
<!ENTITY hArr "&#8660;">
<!ENTITY vArr "&#8661;">
<!ENTITY nwArr "&#8662;">
<!ENTITY neArr "&#8663;">
<!ENTITY seArr "&#8664;">
<!ENTITY swArr "&#8665;">
<!ENTITY larr "&#8592;">
<!ENTITY uarr "&#8593;">
<!ENTITY rarr "&#8594;">
<!ENTITY darr "&#8595;">
<!ENTITY harr "&#8596;">
<!ENTITY varr "&#8597;">
<!ENTITY nwarr "&#8598;">
<!ENTITY nearr "&#8599;">
<!ENTITY searr "&#8600;">
<!ENTITY swarr "&#8601;">
<!ENTITY times "&#215;">
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
    [object] $attachments = @{}

    ConfluDAO([string]$base_url, [string] $page_id) {
        [ConfluDAO]::getPAT() | Out-Null
        $this.Load($base_url, $page_id)
    }
    ConfluDAO() {
        [ConfluDAO]::getPAT() | Out-Null
    }
    ConfluDAO([string]$base_url, [string] $space_key, [string] $parent_id, [string]$title, [string]$page) {
        $this.page_id = [ConfluDAO]::Search($base_url, $title)
        
        if ($this.page_id -eq "") {
            $this.page_id = [ConfluDAO]::Create($base_url, $space_key, $parent_id, $title, $page)
        }
        $this.Load($base_url, $this.page_id)
    }
    static [string]Create([string]$base_url, [string] $space_key, [string] $parent_id, [string]$title, [string]$page) {
        [ConfluDAO]::getPAT() | Out-Null      
        $payload = @{
            title     = $title
            space     = @{key = $space_key }
            type      = "page"
            ancestors = @(@{id = $parent_id })
            body      = @{
                storage = @{
                    representation = "storage"
                    value          = $page
                }
            }
        }
        $json = ConvertTo-JSON -Compress $payload
        $response = Invoke-RestMethod -Uri $base_url -Body $json -Method "POST" -Headers ([ConfluDAO]::headers) -ErrorVariable RespErr   
        return $response.id
    }
    static [string]Search([string]$base_url, [string]$title) {
        [ConfluDAO]::getPAT() | Out-Null      
        $url = $base_url + "?title=" + $title
        $response = Invoke-RestMethod -Uri $url -Method "GET" -Headers ([ConfluDAO]::headers)      
        $id = ""
        if ($response.results.Count -gt 0 ) {
            $id = $response.results.id
        }
        return $id
    }
    [boolean]Load2([string]$base_url, [string]$page_id) {
        $this.base_url = $base_url
        $this.page_id = $page_id
        $url = $this.base_url + "/" + $this.page_id + "?expand=body.storage,version"

        $response = Invoke-WebRequest -Uri $url -Method "GET" -Headers ([ConfluDAO]::headers)
        $content = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding("UTF-8").GetBytes($response.Content))
        $json = ConvertFrom-JSON $content
        $this.page = $json.body.storage.value
        $this.vernum = $json.version.number
        $this.title = $json.title
                
        $this.LoadXml([ConfluDAO]::toXML($this.page))           
        return $true
    }
    [boolean]Load([string]$base_url, [string]$page_id) {
        $this.base_url = $base_url
        $this.page_id = $page_id
        $url = $this.base_url + "/" + $this.page_id + "?expand=body.storage,version"

        $response = Invoke-RestMethod -Uri $url -Method "GET" -Headers ([ConfluDAO]::headers)
        $this.page = $response.body.storage.value
        $this.vernum = $response.version.number
        $this.title = $response.title
                
        #        [ConfluDAO]::toXML($this.page) | Set-Content -Path "h:\tmp\page.xml"
        $this.LoadXml([ConfluDAO]::toXML($this.page))           

        $url = $this.base_url + "/" + $this.page_id + "/child/attachment"
        $_headers = @{
            "Authorization"     = "Bearer " + [ConfluDAO]::getPAT()
            "X-Atlassian-Token" = "no-check"
        }
        $response = Invoke-RestMethod -Uri $url -Method "GET" -Headers $_headers
        $response.results | ForEach-Object { $this.attachments.Add($_.title, $_.id) }

        return $true
    }
    [Object] Save() {
        $url = $this.base_url + "/" + $this.page_id

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
        $response = Invoke-RestMethod -Uri $url -Body $json -Method "PUT" -Headers ([ConfluDAO]::headers) -ErrorVariable RespErr
        $this.vernum ++
        
        return $payload
    }
    [Object] upload([String]$filePath) {
        $url = $this.base_url + "/" + $this.page_id + "/child/attachment"
        $name = $filePath -replace '^.+\\([^\\]+)$', '$1' 

        $_headers = @{
            "Authorization"     = "Bearer " + [ConfluDAO]::getPAT()
            "X-Atlassian-Token" = "no-check"
        }

        if ($this.attachments.ContainsKey($name)) {
            $url = "$url/" + $this.attachments[$name] + "/data"       
        }

        $Form = @{ file = Get-ChildItem $filePath; comment = "UPDATE" }
        $response = Invoke-RestMethod -Uri $url -Method "POST" -Headers $_headers -Form $Form
  
        return $response
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
                "Authorization" = "Bearer " + $settings.rawToken
                "Content-Type"  = "application/json; charset=UTF-8"
            }
        }
        else {
            $cred = Get-Credential
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)
            $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) 
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $cred.UserName, $password)))

            [ConfluDAO]::headers = @{
                Authorization  = ("Basic {0}" -f $base64AuthInfo)
                "Content-Type" = "application/json; charset=UTF-8"
            }   
        }
        if ($settings.expiringAt -eq $null -or [DateTime]$settings.expiringAt -lt (Get-Date).AddDays(20)) {
            $baseUrl = "https://sd10.aslead.cloud/wiki/rest/pat/latest/tokens"   
            $body = @{
                name               = "myToken"
                expirationDuration = 90
            }
            $json = ConvertTo-JSON -Compress $body
            $settings = Invoke-RestMethod -Uri $baseurl -Body $json -Method "POST" -Headers ([ConfluDAO]::headers)
            [ConfluDAO]::setPAT($settings)
        }
        return [ConfluDAO]::token
    }
    static [void] setPAT([object]$settings) {
        $file = "$PSScriptRoot\Conflu.settings.json"
        [ConfluDAO]::token = $settings.rawToken
        [ConfluDAO]::headers = @{
            "Authorization" = "Bearer " + [ConfluDAO]::token
            "Content-Type"  = "application/json; charset=UTF-8"
        }
        ConvertTo-JSON $settings | Set-Content $file
    }
} 
class TsTaskDao {
    [string]$taskName
    [string]$taskPath
    [xml]$xml

    TsTaskDao($taskName, $taskPath) {
        $this.taskName = $taskName
        $this.taskPath = $taskPath
 
        $existFlg = (Get-ScheduledTask -TaskPath $taskPath | Where-Object TaskName -eq $taskName) -ne $null

        if (-not $existFlg) {
            $action = New-ScheduledTaskAction -Execute "%ProgramFiles%\PowerShell\7\pwsh.exe" -Argument "-ExecutionPolicy Bypass <Scripts>"
            Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action
        }        
        $this.xml = [xml](Export-ScheduledTask -TaskName $this.taskName -TaskPath $this.taskPath)       

        if (-not $existFlg) {
            Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false
        }
    }
    TsTaskDao($taskName, $taskPath, $scripts) {
        $this.taskName = $taskName
        $this.taskPath = $taskPath

        $action = New-ScheduledTaskAction -Execute "%ProgramFiles%\PowerShell\7\pwsh.exe" -Argument "-ExecutionPolicy Bypass $scripts"
        Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Force
        $this.xml = [xml](Export-ScheduledTask -TaskName $this.taskName -TaskPath $this.taskPath)       
        Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false
    }
    RemoveAllTrigger() {
        $this.xml.SelectSingleNode("//*[local-name()='Triggers']").RemoveAll()
    }
    AppendMonthlyTrigger ([string]$TriggerTime, [string[]]$Days) {
        $ns = $this.xml.Task.NamespaceURI
            
        # 新しいトリガを作成
        $newTrigger = $this.xml.CreateElement("CalendarTrigger", $ns)
     
        $startBoundary = $this.xml.CreateElement("StartBoundary", $ns)
        $startBoundary.InnerText = ([datetime]$TriggerTime).ToString("yyyy-MM-ddTHH:mm:ss")
        $newTrigger.AppendChild($startBoundary)
    
        $scheduleByMonth = $this.xml.CreateElement("ScheduleByMonth", $ns)
        $daysOfMonth = $this.xml.CreateElement("DaysOfMonth", $ns)
        $days | % {
            $day = $this.xml.CreateElement("Day", $ns)
            $day.InnerText = $_
            $daysOfMonth.AppendChild($day)
        }
        $scheduleByMonth.AppendChild($daysOfMonth)
        $months = $this.xml.CreateElement("Months", $ns)
        ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"
    ) | % {
            $month = $this.xml.CreateElement($_, $ns)
            $months.AppendChild($month)
        }
        $scheduleByMonth.AppendChild($months)
        $newTrigger.AppendChild($scheduleByMonth)
        
        # トリガを追加
        $this.xml.SelectSingleNode("//*[local-name()='Triggers']").AppendChild($newTrigger)
    }
    AppendWeeklyTrigger ([string]$TriggerTime, [string[]]$days) {
        $ns = $this.xml.Task.NamespaceURI
            
        # 新しいトリガを作成
        $newTrigger = $this.xml.CreateElement("CalendarTrigger", $ns)
     
        $startBoundary = $this.xml.CreateElement("StartBoundary", $ns)
        $startBoundary.InnerText = ([datetime]$TriggerTime).ToString("yyyy-MM-ddTHH:mm:ss")
        $newTrigger.AppendChild($startBoundary)
    
        $scheduleByWeek = $this.xml.CreateElement("ScheduleByWeek", $ns)

        $weeksInterval = $this.xml.CreateElement("WeeksInterval", $ns)
        $weeksInterval.InnerText = "1"
        $scheduleByWeek.AppendChild($weeksInterval)

        $daysOfWeek = $this.xml.CreateElement("DaysOfWeek", $ns)
        $days | % {
            $day = $this.xml.CreateElement($_, $ns)
            $daysOfWeek.AppendChild($day)
        }
        $scheduleByWeek.AppendChild($daysOfWeek)

        $newTrigger.AppendChild($scheduleByWeek)
        
        # トリガを追加
        $this.xml.SelectSingleNode("//*[local-name()='Triggers']").AppendChild($newTrigger)
    }
}
class OTTaskSchedulerDAO {
    [string]$taskPath = "\マイタスク\"
    [TsTaskDAO[]]$table

    OtTaskSchedulerDAO($taskPath) {
        $this.taskPath = $taskPath
        $this.GetTasks()
    }
    OtTaskSchedulerDAO() {
        $this.GetTasks()
    }
    Register ([TsTaskDAO]$task) {
        $settings = getCred
        Register-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath -Xml $task.xml.OuterXml -User $settings.id -Password $settings.password -Force  
    }
    SetTrigger([TsTaskDAO]$task, [ciminstance]$trigger) {
        $settings = getCred
        Set-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath -Trigger $trigger -User $settings.id -Password $settings.password  
    }
    GetTasks() {
        $this.table = Get-ScheduledTask -TaskPath $this.taskPath | % { New-Object TsTaskDAO($_.TaskName, $this.taskPath) }
    }
    ReRegisterAll() {
        $settings = getCred
        foreach ($task in $this.table) {
            Set-ScheduledTask -TaskName $task.taskName -TaskPath $this.taskPath -User $settings.id -Password $settings.password  
        }
    }
}

function getCred() {
    $file = "$PSScriptRoot\OfficeTools.settings.json"
    $settings = @{}
    if (!(Test-Path $file -NewerThan (Get-Date).addMonths(-6))) {
        $empNo = Read-Host "社員コードは？(ex.x1234)"
        $cred = Get-Credential
        $settings.add("empNo", $empNo)
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
function setCred() {
    $file = "$PSScriptRoot\OfficeTools.settings.json"
    $settings = @{}
    $empNo = Read-Host "社員コードは？(ex.x1234)"
    $cred = Get-Credential
    $settings.add("empNo", $empNo)
    $settings.add("id", $cred.UserName)
    $settings.add("password", (ConvertFrom-SecureString -SecureString $cred.Password))
    ConvertTo-JSON $settings | Set-Content $file
}
function changeCred() {
    $file = "$PSScriptRoot\OfficeTools.settings.json"
    $settings = getCred
    $cred = Get-Credential -Username $settings.id

    $driver = Start-SeDriver -Browser Edge
    $driver.url = "http://comainu.cu.nri.co.jp/passwd_change/"

    sleep 2

    $driver.FindElementByName('AuthenticationID').sendKeys($settings.empNo)
    $driver.FindElementByName('OldPassword').sendKeys($settings.password)
    $driver.FindElementByName('NewPassword').sendKeys($cred.Password)
    $driver.FindElementByName('NewPasswordConfirm').sendKeys($cred.Password)
    $driver.FindElementByName('ChangePasswordButton').click()
    $driver.SwitchTo().Alert().Accept()

    $settings.password = ConvertFrom-SecureString -SecureString $cred.Password 
    ConvertTo-JSON $settings | Set-Content $file
}
class MattermostDAO {
    static [string] $pat = "hogehoge"
    static [object] $headers = @{
        "Authorization" = "Bearer $pat"
        "Content-Type"  = "application/json; charset=UTF-8"
    }
    [string] $base_url
    [object] $me
    [object] $users
    [object] $posts
    $selectheader = @(
        @{label = "ID"; expression = { $_.id } } ,
        @{label = "日付"; expression = { (Get-Date("1970/1/1")).AddMilliseconds($_.create_at ) } },
        @{label = "投稿者"; expression = { $uid = $_.user_id; ($users | Where-Object { $_.id -eq $uid }).first_name } }
        @{label = "投稿内容"; expression = { $_.message } }
    )
    MattermostDAO([string]$base_url) {
        [MattermostDAO]::getPAT() | Out-Null
        $this.base_url = $base_url
        $this.me = $this.GetMe()
    }
    MattermostDAO() {
        [MattermostDAO]::getPAT() | Out-Null
    }
    [Object] Post($channel_id, $message) {
        $url = $this.base_url + "/posts"
        $payload = @{
            "channel_id" = $channel_id
            "message"    = $message
        }
        $json = ConvertTo-JSON -Compress $payload
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "POST" -Body $json
        return $payload
    }
    [Object] GetPosts($channel_id) {
        $url = $this.base_url + "/channels/" + $channel_id + "/posts"   
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "GET"
        $this.posts = $response.order | % { $response.posts.$_ } 
        $this.users = $this.GetUsers(($this.posts.user_id | Select-Object -Unique))
        return $this.posts
    }
    [Object] DeletePost($post_id) {
        $url = $this.base_url + "/posts/" + $post_id 
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "DEL"
        return $response
    }
    [Object] GetUsers($ids) {
        $url = $this.base_url + "/users/ids" 
        $json = ConvertTo-JSON -Compress $ids
        $response = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "POST" -Body $json
        return $response
    }
    [Object] GetMe() {
        $url = $this.base_url + "/users/me" 
        $this.me = Invoke-RestMethod -Uri $url -Headers ([MattermostDAO]::headers) -Method "GET" 
        return $this.me
    }
    static [string] getPAT() {
        $file = "$PSScriptRoot\Mattermost.settings.json"
        $settings = @{}
        if (Test-Path $file) {
            $settings = Get-Content $file | ConvertFrom-JSON
            [MattermostDAO]::pat = $settings.pat
            [MattermostDAO]::headers = @{
                "Authorization" = "Bearer " + $settings.pat
                "Content-Type"  = "application/json; charset=UTF-8"
            }
        }
        else {
            [MattermostDAO]::pat = Read-Host "MattermostのPATは？"
            $settings.add("pat", [MattermostDAO]::pat)
            [MattermostDAO]::headers = @{
                Authorization  = "Bearer " + $settings.pat
                "Content-Type" = "application/json; charset=UTF-8"
            } 
            ConvertTo-JSON $settings | Set-Content $file
        }
        return [MattermostDAO]::pat
    }
    static [void] setPAT([object]$settings) {
        $file = "$PSScriptRoot\Mattermost.settings.json"
        [MattermostDAO]::pat = $settings.pat
        [MattermostDAO]::headers = @{
            "Authorization" = "Bearer " + [MattermostDAO]::pat
            "Content-Type"  = "application/json; charset=UTF-8"
        }
        ConvertTo-JSON $settings | Set-Content $file
    }


}
class OTCalDAO {
    static [object] $syukujitsu = $null
    static [void] loadSyukujitsu() {
        if (!(Test-Path "$PSScriptRoot\syukujitsu.csv" -NewerThan (Get-Date).addMonths(-6))) {
            $url = 'https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv'
            Invoke-WebRequest -URI $url -OutFile "$PSScriptRoot\syukujitsu.csv"
        } 
        if ((Get-Host).Version.Major -eq 7) {
            [OTCalDAO]::syukujitsu = Import-Csv "$PSScriptRoot\syukujitsu.csv" -Encoding ANSI
        }
        else {
            [OTCalDAO]::syukujitsu = Import-Csv "$PSScriptRoot\syukujitsu.csv" -Encoding Default 
        }
    }
    static [object] getSyukujitsu([datetime]$st, [datetime]$ed) {
        return [OTCalDAO]::syukujitsu | Where-Object { ($st -lt (Get-Date($_."国民の祝日・休日月日"))) -and ((Get-Date($_."国民の祝日・休日月日")) -lt $ed) }
    }
    static [object] getSyukujitsu([Term]$term) {
        return [OTCalDAO]::getSyukujitsu($term.start, $term.end) 
    }
    static [object] getSyukujitsu([string]$st, [string]$ed) {
        return [OTCalDAO]::getSyukujitsu((Get-Date($st)), (Get-Date($ed)))
    }
    static [object] getSyukujitsu([datetime]$st) {
        return [OTCalDAO]::getSyukujitsu($st, $st.AddYears(1))
    }
}
class Term {
    [datetime] $base
    [datetime] $start
    [datetime] $end
    
    Term([datetime]$_base) {
        $this.base = $_base
        $this.start = Get-Date($_base.toString("yyyy/MM/dd"))
        $this.end = $this.start.addDays(1)
    }
    Term([datetime]$st, [datetime]$ed) {
        $this.base = $st
        $this.start = $st
        $this.end = $ed
    }
    Term([datetime]$_base, [string]$span) {
        # span 1:month, 2:half, 3:year
        $this.base = $_base
        switch ($span) {
            "1" {
                $this.start = Get-Date($_base.toString("yyyy/MM/1"))
                $this.end = $this.start.addMonths(1)
            }
            "2" {
                $diff = switch ($_base.Month) { { (4 -le $_) -and ($_ -le 9) } { 4 }; default { 10 } } 
                $this.start = Get-Date($_base.AddMonths($diff - $_base.Month).toString("yyyy/MM/1"))
                $this.end = $this.start.AddMonths(6)
            }
            "3" {
                $diff = switch ($_base.Month) { { 4 -le $_ } { 4 }; default { -8 } } 
                $this.start = Get-Date($_base.AddMonths($diff - $_base.Month).toString("yyyy/MM/1"))
                $this.end = $this.start.AddMonths(12)
            }
            default {}
        } 
    }
    [boolean] Contains([datetime]$dt) {
        return ($this.start -le $dt) -and ($dt -lt $this.end)
    }
    [Term] ThisMonth() {
        return New-Object Term($this.base, 1)
    }
    [Term] PrevMonth() {
        return New-Object Term($this.base.addMonts(-1), 1)
    }
    [Term] Half() {
        return New-Object Term($this.base, 2)
    }
    [Term[]] HalfMonths() {
        $diff = switch ($this.base.Month) { { (4 -le $_) -and ($_ -le 9) } { 4 }; default { 10 } } 
        $diff -= $this.base.Month
        return $diff..0 | ForEach-Object { New-Object Term($this.base.addmonths($_), 1) }
    }
}
function isHoliday([datetime]$date) {
    if ([OTCalDAO]::syukujitsu -eq $null) { [OTCalDAO]::loadSyukujitsu() }
    $holiday = ([OTCalDAO]::syukujitsu | Where-Object "国民の祝日・休日月日" -eq $date.ToString("yyyy/M/d"))."国民の祝日・休日名称"
    return $holiday
}
#
# 日付クラスの拡張
#
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
Get-TypeData -TypeName System.DateTime | Remove-TypeData
Update-TypeData -TypeName System.DateTime -MemberType ScriptProperty -MemberName Holiday -Value $Holiday
Update-TypeData -TypeName System.DateTime -MemberType ScriptProperty -MemberName isHoliday -Value $isHoliday
Update-TypeData -TypeName System.DateTime -MemberType ScriptMethod -MemberName AddWorkDays -Value $AddWorkDays
Update-TypeData -TypeName System.DateTime -MemberType ScriptProperty -MemberName isWorkDay -Value $isWorkDay

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
function downloadCript([string]$url, [string]$key, [string]$downloadPath) {
    $settings = getCred
    node "$PSScriptRoot\downloadCript.js" -u $url -k $key --id $settings.id --pw $settings.pw -d $downloadPath
}
function Invoke-WebRequest2() {
    [OutputType([HtmlAgilityPack.HtmlDocument])]
    param(
        [string]$url
    )

    # 現在のコンソールのエンコーディングを一時的に保存
    $originalEncoding = [System.Console]::OutputEncoding

    try {
        # コンソールの出力エンコーディングをUTF-8に設定
        [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        # Node.jsスクリプトを実行し、UTF-8として出力された結果を
        # 単一の文字列として受け取る
        $html = node "$PSScriptRoot\render.js" $url | Out-String
    }
    finally {
        # 処理が終わったら、成功・失敗にかかわらず元のエンコーディングに戻す
        [System.Console]::OutputEncoding = $originalEncoding
    }

    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($html)
   
    return $doc   
}
