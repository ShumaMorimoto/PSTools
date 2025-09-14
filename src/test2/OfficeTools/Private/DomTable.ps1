DomTable([System.Xml.XmlElement]$table) {
        $this.element = $table
        $this.header = $table.GetElementsByTagName("th") | ForEach-Object { $_.innerText }
    }
