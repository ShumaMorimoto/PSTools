class OlMailTable:AbstractTable {
    [object]$folder
    [object]$items
    
    static $selectheader = @(
        @{label = "受信日時"; expression = { $_.ReceivedTime } },
        @{label = "送信者"; expression = { $_.Sender.Address } },
        @{label = "宛先"; expression = { $_.To } },
        @{label = "CC"; expression = { $_.Cc } },
        "Subject", "Body", "EntryID"
    )   
    OlMailTable([object]$folder) {
        $this.folder = $folder
        $this.items = $this.folder.items
        $this.items.Sort("[ReceivedTime]")
    }
    [pscustomobject] toObject() {
        return [OlMailTable]::toObject($this.items)
    }
    static [pscustomobject] toObject([object]$items) {
        return [pscustomobject]@{
            header = @("受信日時", "送信者", "宛先", "CC", "Subject", "Body", "EntryID")
            data   = $items | Select-Object ([OlMailTable]::selectheader)
        }
    }
    [object] Search([pscustomobject]$data, [ScriptBlock] $compfunc) {
        return $this.items | Where-Object { &$compfunc $_ $data }
    }
    [object] GetUnreadMails([string] $startDT, [string] $endDT) {
        $filter = "[UnRead] =True AND [ReceivedTime] < '$endDT' AND [ReceivedTime] > '$startDT'"
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items = $this.folder.items.Restrict($filter)
        return $this.items
    }
    [object] GetUnreadMails() {
        return $this.GetUnreadMails(1)
    }
    [object] GetUnreadMails([int]$term) {
        $date = Get-Date
        return $this.GetUnreadMails($date.addDays(-$term).toString("yyyy/M/d 23:59"), $date.toString("yyyy/M/d 23:59"))
    }
    [object] GetMails([string] $startDT, [string] $endDT) {
        $filter = "[ReceivedTime] < '$endDT' AND [ReceivedTime] > '$startDT'"
        $this.items = $this.folder.items       
        $this.items.IncludeRecurrences = $true       
        $this.items = $this.folder.items.Restrict($filter)
        return $this.items
    }
    [object] GetMails() {
        return $this.GetMails(1)
    }
    [object] GetMails([int]$term) {
        $date = Get-Date
        return $this.GetMails($date.addDays(-$term).toString("yyyy/M/d 23:59"), $date.toString("yyyy/M/d 23:59"))
    }
    [void] Sort([ScriptBlock] $orderfunc) {
        $this.items.Sort("[ReceivedTime]")
    }
    [void] AddMail([object]$item) {
        $item | ForEach-Object { $_.Move($this.folder) }
    }
    [OlMailTable] GetMailTable([string]$path) {
        $subfolder = $this.folder
        $path -split "\\" | select-object -skip 2 | ForEach-Object { $subfolder = $subfolder.folders($_) }
        return New-Object OLMailTable($subfolder)
    }
    [object]Restrict([Object]$keywords) { 
        $this.items = [OTOutlookDAO]::filterItems($this.items, $keywords)
        return $this.items
    }
}
