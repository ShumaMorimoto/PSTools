SetHeader([string[]] $header) { 
        $tbody = $this.element.AppendChild($this.element.OwnerDocument.CreateElement("tbody"))
        $tr = $tbody.AppendChild($this.element.OwnerDocument.CreateElement("tr")) 
        $header | ForEach-Object {
            $tr.AppendChild($this.element.OwnerDocument.CreateElement("th")).InnerText = $_
        }
        $this.header = $header
        return [System.Xml.XmlElement]$tr
    }
