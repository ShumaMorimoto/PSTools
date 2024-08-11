class AbstractTable {
    [object] $header

    [object] toObject() {
        return $null
    }
    [object] toJSON() {
        return ConvertTo-JSON $this.toObject()
    }
    [object] Search([Object]$data, [ScriptBlock] $compfunc) {
        return $null
    }
    [void] Sort([ScriptBlock] $orderfunc) {
    }
    [object]AddRow([Object] $data) { 
        return $null
    }
    [object]SetHeader([Object] $header) { 
        return $null
    }
}
class DomTable : AbstractTable {
    [System.Xml.XmlElement] $element

    DomTable([System.Xml.XmlElement]$table, [object]$header) {
        $this.element = $table
        $this.SetHeader($header) | Out-Null
    }
    [object] toObject() {
        $data = @() 
        $this.element.tbody.tr | Where-Object { $_.td.length -gt 0 } | ForEach-Object {
            $dt = [array] $_.td
            $dt2 = @{}
            for ($i = 0; $i -lt $this.header.length; $i++) {
                $dt2 += @{$this.header[$i] = $dt[$i] }
            }
            $data += $dt2
        }
        return @{header = $this.header; data = $data }
    }
    [object] Search([Object]$data, [ScriptBlock] $compfunc) {
        return $this.element.tbody.tr | Where-Object { $_.td.length -gt 0 } | Where-Object { &$compfunc $_ $data }
    }
    [void] Sort([ScriptBlock] $orderfunc) {
        $this.element.tbody.tr | Where-Object { $_.td.length -gt 0 } | Sort-Object -Property @{Exp = { &$orderfunc $_ } } | ForEach-Object { $this.element.tbody.appendChild($_) } | Out-Null
    }
    [System.xml.XmlElement]AddRow([Object] $data) { 
        foreach ($d in $data) {
            $tr = $this.element.tbody.AppendChild($this.element.OwnerDocument.CreateElement("tr")) 
            $this.header | ForEach-Object { $tr.AppendChild($this.element.OwnerDocument.CreateElement("td")).InnerText = $d[$_] }
        }
        return $this.element
    }
    [System.xml.XmlElement]SetHeader([Object] $header) { 
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
    [object]$tables
    
    OTDomDAO([string]$xml) {
        $this.LoadXML($xml)  
    }
    [void]LoadXML($xml) {
        [System.Xml.XmlDocument]$this.LoadXML($xml)
        $this.tables = $this.GetElementsByTagName("table")
    }
    [DomTable]CreateTable([object] $tdata) {
        $element = $this.CreateElement("table")
        $table = New-Object DomTable($element, $tdata.header)
        $tdata.data | ForEach-Object { $table.AddRow($_) | Out-Null }
        $this.tables += $table
        return $table
    }
    [object] GetTables() {       
        return ($this.getElementsByTagName("table") | ForEach-Object { New-Object DomTTable($_) })
    }
}
class ExTable {
    [object] $range
    [object] $table

    ExTable([object]$range) {
        $this.range = $range
        $this.header = $this.GetHeader()
        #        $this.table = $this.GetTable()
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
            }
            $rrange = $rrange.Offset(1, 0)
        }
        return $this.range
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
    [Object] toObject() {
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
    [object] $tables =@{}

    [void]Show() {
        if (-not [OTExcelDAO]::excel.Visible) {
            [OTExcelDAO]::excel.Visible = $true
            if ($this.book.ReadOnly) { $this.book.ChangeFileAccess(2) }
        } 
    }
    [void]Close() {
        $this.book.close()
    }
    OTExcelDAO([string]$path, [boolean]$readOnly=$true) {
        $this.initialize($path, $readOnly)
    }
    [void] initialize([string]$path, [boolean]$readOnly) {
        if ($null -eq [OTExcelDAO]::excel) {
            [OTExcelDAO]::excel = New-Object -ComObject Excel.Application
        }
        if ($path -match "[^\\]+\.xls[m]*") {
            $bookname = $Matches[0]
            $this.book = [OTExcelDAO]::excel.Workbooks | Where-Object Name -eq $bookname
            if ($null -eq $this.book ) {
                $this.book = [OTExcelDAO]::excel.Workbooks.Open($path, 0, $readOnly)
            }
        }
    }
    [Object] GetTable([string]$sheetname, [string]$address) {
        $sheet = $this.book.Worksheets($sheetname)
        $range = $sheet.Range($address)
        $table = New-Object ExTable($range)
        $this.tables.Add($sheetname,$table)
        return $table
    }
}
