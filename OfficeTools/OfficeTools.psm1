Class DMTableDAO :System.Xml.XmlDocument {
    [object]$tables
    
    DMTableDAO([string]$xml) {
        $this.LoadXML($xml)  
    }
    DMTableDAO() {
    }
    [void]LoadXML($xml) {
        [System.Xml.XmlDocument]$this.LoadXML($xml)
        $this.tables = $this.GetElementsByTagName("table")
    }
    [object]CreateTable([object] $tdata) {
        $table = $this.CreateElement("table")
        $tr = $table.AppendChild($this.CreateElement("tbody")).AppendChild($this.CreateElement("tr"))
        $tdata.header | ForEach-Object { $tr.AppendChild($this.CreateElement("th")).InnerText = $_ }
        $tdata.data | ForEach-Object { $this.Addrow($table, $tdata.header, $_) | Out-Null }
        $this.tables = $this.GetElementsByTagName("table")
        return $this.ChildNodes[0].appendChild($table)
    }
    [object]Addrow([System.xml.XmlElement]$table, [object]$header, [Object] $data) { 
        $tr = $table.tbody.AppendChild($this.CreateElement("tr")) 
        $header | ForEach-Object { $tr.AppendChild($this.CreateElement("td")).InnerText = $data[$_] }
        return [System.Xml.XmlElement]$tr
    }
    [object] GetTables() {       
        return ($this.getElementsByTagName("table") | ForEach-Object { $this.GetTable($_) })
    }
    [object] GetTable($table) {
        $header = [array]$table.tbody.tr[0].th 
        $data = @() 
        $table.tbody.tr | Where-Object { $_.td.length -gt 0 } | ForEach-Object {
            $dt = [array] $_.td
            $dt2 = @{}
            for ($i = 0; $i -lt $header.length; $i++) {
                $dt2 += @{$header[$i] = $dt[$i] }
            }
            $data += $dt2
        }
        return @{header = $header; data = $data }
    }
    static [object] Search([System.Xml.XmlElement]$table, [Object]$data, [ScriptBlock] $compfunc) {
        return $table.tbody.tr | Where-Object { $_.td.length -gt 0 } | Where-Object { &$compfunc $_ $data }
    }
    static [void] Sort([System.xml.XmlElement]$table, [ScriptBlock] $orderfunc) {
        $table.tbody.tr | Where-Object { $_.td.length -gt 0 } | Sort-Object -Property @{Exp = { &$orderfunc $_ } } | ForEach-Object { $table.tbody.appendChild($_) } | Out-Null
    }
}
class OutlookDAO {
    static [object] $outlook
    static [object] $namespace
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
        if ($null -eq [OutlookDAO]::outlook) {
            [OutlookDAO]::outlook = New-Object -ComObject Outlook.Application
            [OutlookDAO]::namespace = [OutlookDAO]::outlook.GetNamespace("MAPI")
        }
    }
    [void] setFolder() {
        $this.folder = [OutlookDAO]::namespace.GetDefaultFolder(9) 
    }
    [void] setFolder([string]$reciever) {
        $rec = [OutlookDAO]::namespace.CreateRecipient($reciever)
        $this.folder = [OutlookDAO]::namespace.GetSharedDefaultFolder($rec, 9) 
    }
    [object] getApo([object] $id) {
        return [OutlookDAO]::namespace.GetItemFromID($id)
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
        $startDT = [OutlookDAO]::formatDT($startDT)
        $endDT = [OutlookDAO]::formatDT($endDT)
        $filter = "[Start] = '$startDT' AND [End] = '$endDT'"
        return $items.Restrict($filter)
    }
    [object] createMail() {
        return [OutlookDAO]::outlook.CreateItem(0)
    }
    [object] createApo([object]$startDT, [object]$endDT) {
        $item = $this.folder.Items.Add()
        $item.Start = [OutlookDAO]::FormatDT($startDT)
        $item.End = [OutlookDAO]::formatDT($endDT)
        return $item
    }
    static [object] filter([Object]$items, [Object]$keywords) { 
        $filter = "@SQL=urn:schemas:httpmail:subject LIKE '" + [string]::Join("' OR urn:schemas:httpmail:subject LIKE '", $keywords) + "'" 
        return $items.Restrict($filter)
    }
    static [string] formatDT ([Object]$dt) {
        if ($dt -is [datetime]) { $dt = $dt.toString("yyyy/M/d HH:mm") } 
        return $dt
    }
}
class EXTableDAO {
    static [object] $excel
    [object] $book
    [object] $sheet
    [object] $range
    [object] $header
    [object] $table

    [void]Show() {
        if (-not [EXtableDAO]::excel.Visible) {
            [EXtableDAO]::excel.Visible = $true
            $this.book.ChangeFileAccess(2)
        } 
    }
    [void]Close() {
        $this.book.close()
    }
    EXTableDAO([string]$path, [string]$sheetname, [string]$address) {
        $this.initialize($path, $sheetname)

        $this.range = $this.sheet.Range($address)
        $this.header = $this.GetHeader()
        #        $this.table = $this.GetTable()
    }
    EXTableDAO([string]$path, [string]$sheetname) {
        $this.initialize($path, $sheetname)
    }
    [void] initialize([string]$path, [string]$sheetname) {
        if ($null -eq [EXtableDAO]::excel) {
            [EXtableDAO]::excel = New-Object -ComObject Excel.Application
        }
        if ($path -match "[^\\]+\.xls[m]*") {
            $bookname = $Matches[0]
            $this.book = [EXtableDAO]::excel.Workbooks | Where-Object Name -eq $bookname
            if ($null -eq $this.book ) {
                $this.book = [EXtableDAO]::excel.Workbooks.Open($path, 0, $true)
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
        $this.show()
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
        $r = $this.range.Offset($this.range.Rows.Count, 0)
        if ($r.Cells(1, 1) -eq "") { $r = $null }
        else {
            $r = $r.Resize($r.End(-4121).row - $r.row + 1)
        }
        return $r
    }
    [boolean] Sort([ScriptBlock] $orderfunc) {
        $this.Show()

        $rrange = $this.GetRange()
        $keycol = $this.sheet.Columns.Count
        $rrange = $rrange.Resize($rrange.Rows.Count, $keycol)
        $key = $rrange.columns[$keycol]
    
        $rrange.rows | ForEach-Object { $_.Columns[$keycol] = &$orderfunc $_ }
        # $key.ClearContents()

        return $rrange.Sort($key, 1)
    }   
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
class PPTableDAO {
    static [object] $powerpoint
    [object] $presen
    [object] $table

    PPTableDAO([string]$path) {
        $this.initialize()
        $this.presen = [PPTableDAO]::powerpoint.Presentations.Open($path)
    }
    [void] initialize() {
        if ($null -eq [PPTableDAO]::powerpoint) {
            [PPTableDAO]::powerpoint = New-Object -ComObject PowerPoint.Application
        }
    }
    [void] SetHeader([object]$header) {
        $this.header = $header
    }
    [object] GetTablesFromSlide([object]$slide) {       
        return ($slide.shapes | Where-Object { $null -ne $_.table } | ForEach-Object { $_.table })
    }
    [object] GetTables() {
        return ($this.presen.slides | ForEach-Object { ($this.GetTablesFromSlide($_)) })
    }
    [object] GetTable() {
        $tables = $this.presen.slides | ForEach-Object { ($this.GetTablesFromSlide($_)) }
        $data = @()
        $tables | ForEach-Object { 
            $_.rows | ForEach-Object {
                $r = @() 
                $_.Cells | ForEach-Object { $r += $_.Shape.TextFrame.TextRange.Text }
                $data += $null
                $data[$data.length - 1] = $r
            }
        }
        $header = $data[0]
        $data = $data | Where-Object { $_[0] -ne $header[0] }
        $hdata = @()
        $data | ForEach-Object {
            $i = 0; $rc = @{}
            foreach ($key in $header) {
                $rc.add($key, $_[$i])
                $i++
            }
            $rc
            $hdata += $rc
        }
        $this.table = @{
            header = $header
            data   = $hdata
        }
        return $this.table
    }
}