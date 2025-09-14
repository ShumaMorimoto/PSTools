SearchItem([object] $id) {
        return [OTOutlookDAO]::namespace.GetItemFromID($id)
    }
