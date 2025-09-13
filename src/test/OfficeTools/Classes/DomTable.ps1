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
