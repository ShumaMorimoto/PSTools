GetUnsentMailTable() {
        return New-Object OLMailTable([OTOutlookDAO]::namespace.GetDefaultFolder(4))
    }
