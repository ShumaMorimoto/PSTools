CreateTable([pscustomobject] $tdata, [System.Xml.XmlElement] $parent) {
        $element = $this.CreateElement("table")
        $parent.AppendChild($element)
        $table = $this.AppendTable($element)
        $table.SetHeader($tdata.header) | Out-Null
        $table.AddRow($tdata.data) | Out-Null
        return $table
    }
