LoadXML($xml) {
        [System.Xml.XmlDocument]$this.LoadXML($xml)
        $this.GetTables() | Out-Null
    }
