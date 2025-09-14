createMail() {
        return [OTOutlookDAO]::outlook.CreateItem(0)
    }
