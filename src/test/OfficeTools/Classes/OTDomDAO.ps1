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
