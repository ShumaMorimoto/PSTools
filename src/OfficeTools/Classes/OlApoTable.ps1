class OlApoTable:AbstractTable {
    [object]$folder
    [object]$items

    static $selectheader = @(
        @{label = "日付"; expression = { $_.Start.toString("M/d(ddd)") } },
        @{label = "時間"; expression = { $_.Start.toString("HH:mm-") + $_.End.toString("HH:mm") } },
        "Subject", "Location", "Body", "EntryID"
    )

    OlApoTable([object]$folder) {
        $this.folder = $folder
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items.Sort("[Start]")
    }
    [pscustomobject] toObject() {
        return [OlApoTable]::toObject($this.items)
    }
    static [pscustomobject] toObject([object]$items) {
        return [pscustomobject]@{
            header = @("日付", "時間", "Subject", "Location", "Body", "EntryID")
            data   = $items | Select-Object ([OlApoTable]::selectheader) 
        }
    }
    [object] Search([pscustomobject]$data, [ScriptBlock] $compfunc) {
        return $this.items | Where-Object { &$compfunc $_ $data }
    }
    [object] SearchApos([object] $startDT, [object] $endDT) {
        $startDT = [OTOutlookDAO]::formatDT($startDT)
        $endDT = [OTOutlookDAO]::formatDT($endDT)
        $filter = "[Start] = '$startDT' AND [End] = '$endDT'"
        return $this.items.Restrict($filter)
    }
    [object] GetApos([string] $startDT, [string] $endDT) {
        $filter = "[Start] < '$endDT' AND [End] > '$startDT'"   
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items.Sort("[Start]")
        $this.items = $this.items.Restrict($filter)
        return $this.Items
    }
    [object] GetApos() {
        return $this.GetApos(1)
    }
    [object] GetApos([int]$term) {
        $date = Get-Date  
        return $this.GetApos($date.toString("yyyy/M/d 00:00"), $date.adddays($term).toString("yyyy/M/d 00:00"))
    }
    [void] Sort([ScriptBlock] $orderfunc) {
        $this.items.Sort("[Start]")
    }
    [object]CreateApo([pscustomobject] $data) { 
        $item = $this.items.Add()
        $item.Start = [OTOutlookDAO]::FormatDT($data."Start")
        $item.End = [OTOutlookDAO]::formatDT($data."End")
        return $item
    }
    [object]CreateEvent([datetime] $date) { 
        $item = $this.items.Add()
        $item.Start = $date.toString("yyy/M/d 00:00")
        $item.End = $date.addDays(1).toString("yyy/M/d 00:00")
        $item.AllDayEvent = $true
        return $item
    }
    [object]Restrict([Object]$keywords) { 
        $this.items = [OTOutlookDAO]::filterItems($this.items, $keywords)
        return $this.items
    }
}
