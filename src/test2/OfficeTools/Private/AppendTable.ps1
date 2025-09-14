AppendTable([System.Xml.XmlElement] $element, [System.Xml.XmlElement] $parent) {
        $parent.AppendChild($element)
        return $this.AppendTable($element)
    }
