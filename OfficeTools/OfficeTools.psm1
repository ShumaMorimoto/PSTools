function DMSort {
    param ([System.xml.XmlElement]$table, [ScriptBlock] $orderfunc) 
    $table.tbody.tr | Sort-Object -Property @{Exp = { &$orderfunc $_ } } | ForEach-Object { $table.tbody.appendChild($_) } | Out-Null
}
function DMSearch {
    param ([System.Xml.XmlElement]$table, [Object]$data, [ScriptBlock] $compfunc) 
    return $table.tbody.tr | Where-Object { &$compfunc $_ $data }
}
function DMAddrow {
    param ([System.xml.XmlElement]$table, [Object] $data) 
    $tr = $table.tbody.AppendChild($table.ownerdocument.CreateElement("tr")) 
    $header | ForEach-Object { $tr.AppendChild($table.ownerdocument.CreateElement("td")).InnerText = $data[$_] }
    return [System.Xml.XmlElement]$tr
}
function DMAppendrow {
    param ([System.xml.XmlElement]$table, [Object] $data, [ScriptBlock] $compfunc)
    $tr = DMSearch $table $data $compfunc
    if ($tr -eq $null) {
        $tr = DMAddrow $table $data 
    }
    return [System.Xml.XmlElement]$tr
}
function DMCreateTable {
    param ([xml]$doc, [Object] $tdata) 

    $table = $doc.CreateElement("table")
    $tbody = $table.AppendChild($doc.CreateElement("tbody"))
    $tr = $tbody.AppendChild($doc.CreateElement("tr")) 
    
    $tdata.header | ForEach-Object { $tr.AppendChild($doc.CreateElement("th")).InnerText = $_ }
    $tdata.data | ForEach-Object { DMAddrow $table $_ | Out-Null }

    return [System.Xml.XmlElement]$table
}
function DMConvertTable {
    param ([System.xml.XmlElement]$table) 
    $header = [array]$table.tbody.tr[0].th 
    $data = @()    
    foreach ($tr in $table.tbody.tr) {
        if ($tr.td.length -gt 0) {
            $dt = [array] $tr.td
            $dt2 = @{}
            for ($i = 0; $i -lt $header.length; $i++) {
                $dt2 += @{$header[$i] = $dt[$i] }
            }
            $data += $dt2
        }
    }      
    return @{header = $header; data = $data }
}
function OLfilter {
    param ([Object]$items, [Object]$keywords) 

    $filter = "@SQL=urn:schemas:httpmail:subject LIKE '" + [string]::Join("' OR urn:schemas:httpmail:subject LIKE '", $keyword) + "'" 
    return $items.Restrict($filter)
}
function OLformatDT ([Object]$dt) {
    if ($dt -is [datetime]) { $dt = $dt.toString("yyyy/M/d HH:mm") } 
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
        try {
            $this.outlook = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Outlook.Application")
        }
        catch {
            $this.outlook = New-Object -ComObject Outlook.Application
        }
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
class EXTableDAO {
    [object] $excel
    [object] $book
    [object] $sheet
    [object] $range
    [object] $header
    [object] $table

    [void]Show() {
        $this.book.Visible = $true
    }
    [void]Close() {
        $this.book.Quit()
    }
    EXTableDAO([string]$path, [string]$sheetname, [string]$address) {
        $this.initialize($path, $sheetname)

        $this.range = $this.sheet.Range($address)
        $this.header = $this.GetHeader()
        $this.table = $this.GetTable()
    }
    EXTableDAO([string]$path, [string]$sheetname) {
        $this.initialize($path, $sheetname)
    }
    [void] initialize([string]$path, [string]$sheetname) {
        try {
            $this.excel = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
        }
        catch {
            $this.excel = New-Object -ComObject Excel.Application
        }
        if ($path -match "[^\\]+\.xls[m]*") {
            $bookname = $Matches[0]
            $this.book = $this.excel.Workbooks | Where-Object Name -eq $bookname
            if ($this.book -eq $null) {
                $this.book = $this.excel.Workbooks.Open($path, 0, $true)
            }
        }
        $this.sheet = $this.book.Worksheets($sheetname)
    }
    [object] GetHeader() {
        $this.header = @{}
        if ($this.range.rows.count -eq 1) {
            $this.range | ForEach-Object { if ($_.Text -ne "") { $this.header.Add($_.Text, $_) } }  
        }
        else {
            $this.range.rows(1).Columns | ForEach-Object {
                if ($_.Text -ne "") {
                    if ($_.MergeArea.Columns.Count -gt 1) {
                        $this.header.Add($_.Text, $_.Offset(1, 0).Resize(1, $_.MergeArea.Count))
                    }
                    else {    
                        $this.header.Add($_.Text, $_) 
                    }
                }
            }  
        }
        return $this.header  
    }
    [object] AddRow([object]$data) {
        $this.book.ChangeFileAccess(2) | Out-Null   
        $this.excel.Visible = $true
        $rrange = $this.range.End(-4121).Offset(1, 0)

        $data | ForEach-Object {
            $d = $_
            $this.header.keys | ForEach-Object {
                $cell = $this.header[$_]
                if ($cell.MergeArea.Columns.Count -eq 1) {
                    $rrange.Resize(1, 1).Offset(0, $cell.Column - $rrange.Column) = $d[$_]
                }
                elseif ($cell.MergeCells) {
                    if ($d[$_].Count -gt 0) {
                        $rrange.Offset(0, $cell.Column - $rrange.Column).Resize(1, $d[$_].Count) = $d[$_]
                    }
                }
                else {
                }
            }
            $rrange = $rrange.Offset(1, 0)
        }
        $this.book.Save()
        return $this.GetTable()
    }
    [object] GetRow($range) {
        $data = @{}
        $this.header.keys | ForEach-Object {
            $value = ""
            $cell = $this.header[$_]

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
                    if ($vcell.Text -ne "") { $value.Add($_.Text, $vcell.Text) } }
            }
            $data.Add($_, $value)
        }
        return $data
    }
    [Object] GetTable() {
        $rrange = $this.GetRange()
        $data = @()
        $rrange.rows | ForEach-Object { $data += $this.GetRow($_) }  
        $this.table = @{
            header = $this.header.keys | Sort-Object -Property @{Exp = { $this.header[$_].Column } } 
            data   = $data
        }
        return $this.table
    }
    [object] GetRange() {
        return $this.range.Offset($this.range.Rows.Count, 0).Resize($this.range.End(-4121).row - $this.range.row - $this.range.Rows.Count + 1)
    }
    [boolean] Sort([ScriptBlock] $orderfunc) {
        $this.book.ChangeFileAccess(2) | Out-Null   
        $this.excel.Visible = $true

        $rrange = $this.GetRange()
        $keycol = 10
        $rrange = $rrange.Resize($rrange.Rows.Count, $keycol)
        $key = $rrange.columns[$keycol]
    
        $rrange.rows | ForEach-Object { $_.Columns[$keycol] = &$orderfunc $_ }
        # $key.ClearContents()

        return $rrange.Sort($key, 1)
    }
    
}
function datenormalizer {
    param([string]$val1,[string]$val2)
    
    switch -Regex ($val1) {       
        '(\d\d)/(\d+)/(\d+)$' {
            $order = $Matches[1] + $Matches[2].PadLeft(2, "0") + $Matches[3].Padleft(2, "0")
            if ($val2 -match "(\d+):(\d+)") {
                $order += $Matches[1].PadLeft(2, "0") + $Matches[2].PadLeft(2, "0")
            }
            else {
                $order += "9999"
            }
            break
        }
        '(2\d/\d+)' {
            $order = [DateTime]::ParseExact($Matches[1], "yy/M", $null).ToString("yyMM019999")
            break
        }
        '(\d+)  ' {
            $order = (Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1].PadLeft(2, "0") + "019999"
            break
        }
        '(2\d/\d+)[/]*([上中下末])' {
            $date = [DateTime]::ParseExact($Matches[1], "yy/M", $null)
            switch ($Matches[2]) {
                "上" { $order = $date.ToString("yyMM") + "109999" }
                "中" { $order = $date.ToString("yyMM") + "209999" }
                "下" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
                "末" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
            }
            break
        }
        '(\d+)[/]*([上中下末])' {
            $date = [DateTime]::ParseExact((Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1], "yyM", $null)
            switch ($Matches[2]) {
                "上" { $order = $date.ToString("yyMM") + "109999" }
                "中" { $order = $date.ToString("yyMM") + "209999" }
                "下" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
                "末" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
            }
            break
        }
        '(2\d)/(\d+)/(\d+)[週-]*' {
            $order = $Matches[1] + $Matches[2].PadLeft(2, "0") + $Matches[3].Padleft(2, "0") + "9999"
            break
        }
        '(\d+)/(\d+)[週-]*' {
            $order = (Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1].PadLeft(2, "0") + $Matches[2].Padleft(2, "0") + "9999"
            break
        }
        default {$order = "9999999999"}
    }
    return $order
}