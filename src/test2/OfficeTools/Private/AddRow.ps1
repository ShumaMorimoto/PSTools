AddRow([pscustomobject[]] $data) { 
        foreach ($d in $data) {
            $tr = $this.element.tbody.AppendChild($this.element.OwnerDocument.CreateElement("tr")) 
            $this.header | ForEach-Object { $tr.AppendChild($this.element.OwnerDocument.CreateElement("td")).InnerText = $d.$_ }
        }
        return $this.element
    }
