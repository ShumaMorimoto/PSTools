class OTOutlookDAO {
    static [object] $outlook
    static [object] $namespace

    OTOutlookDAO() {
        $this.initialize()
    }
    [void] initialize() {
        try {
            if ($null -ne [OTOutlookDAO]::outlook) {
                [OTOutlookDAO]::namespace = [OTOutlookDAO]::outlook.GetNamespace("MAPI")
            }
            else {
                throw "New Object"
            }
        }
        catch {
            [OTOutlookDAO]::outlook = New-Object -ComObject Outlook.Application
            [OTOutlookDAO]::namespace = [OTOutlookDAO]::outlook.GetNamespace("MAPI")
        }
    }
    [OlApoTable] GetApoTable([string]$receiver) {        
        $folder = switch ($receiver) {
            "" {
                [OTOutlookDAO]::namespace.GetDefaultFolder(9)
            }
            default {
                $rec = [OTOutlookDAO]::namespace.CreateRecipient($receiver)
                [OTOutlookDAO]::namespace.GetSharedDefaultFolder($rec, 9)           
            }
        } 
        return New-Object OlApoTable($folder)
    }
    [object] GetApoTable() {        
        return $this.GetApoTable($null)
    }
    [OlMailTable] GetMailTable() {
        return New-Object OLMailTable([OTOutlookDAO]::namespace.GetDefaultFolder(6))
    }
    [OlMailTable] GetMailTable([string]$path) {
        $folder = [OTOutlookDAO]::namespace
        $path -split "\\" | select-object -skip 2 | ForEach-Object { $folder = $folder.folders($_) }
        return New-Object OLMailTable($folder)
    }
    [OlMailTable] GetUnsentMailTable() {
        return New-Object OLMailTable([OTOutlookDAO]::namespace.GetDefaultFolder(4))
    }
    static [string] formatDT ([Object]$dt) {
        if ($dt -is [datetime]) { $dt = $dt.toString("yyyy/M/d HH:mm") } 
        return $dt
    }
    static [object] filterItems([Object]$items, [Object]$keywords) { 
        $filter = "@SQL=urn:schemas:httpmail:subject LIKE '" + [string]::Join("' OR urn:schemas:httpmail:subject LIKE '", $keywords) + "'" 
        return $items.Restrict($filter)
    }
    [object] SearchItem([object] $id) {
        return [OTOutlookDAO]::namespace.GetItemFromID($id)
    }
    [object] createMail() {
        return [OTOutlookDAO]::outlook.CreateItem(0)
    }
    static [object] ResolveAddress([string]$name) {
        if (($name -eq "") -or $null -eq $name) {
            return $null
        }
        if ($name -match "(.{3})　(.{3})") {   
            $name = ($Matches[1] -replace "　", "") + " " + ($Matches[2] -replace "　", "")
        }
        $recip = [OTOutlookDAO]::namespace.CreateRecipient($name)
        $user = @{氏名 = $name }

        if ($recip.Resolve()) {     
            $user.氏名 = $recip.Name
            $user.メール = $recip.AddressEntry.GetExchangeUser().PrimarySmtpAddress

            if ($recip.Name -match "(.+　.+)\((\d+)\)(.+)$") {
                $user.氏名 = $Matches[1]
                $user.内線番号 = $Matches[2]
                $user.所属 = $Matches[3]
            }
        }       
        return $user
    }
}
