GetMailTable([string]$path) {
        $folder = [OTOutlookDAO]::namespace
        $path -split "\\" | select-object -skip 2 | ForEach-Object { $folder = $folder.folders($_) }
        return New-Object OLMailTable($folder)
    }
