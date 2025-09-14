RemoveAllTrigger() {
        $this.xml.SelectSingleNode("//*[local-name()='Triggers']").RemoveAll()
    }
