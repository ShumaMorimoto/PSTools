SearchApos([object] $startDT, [object] $endDT) {
        $startDT = [OTOutlookDAO]::formatDT($startDT)
        $endDT = [OTOutlookDAO]::formatDT($endDT)
        $filter = "[Start] = '$startDT' AND [End] = '$endDT'"
        return $this.items.Restrict($filter)
    }
