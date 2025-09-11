@{
    RootModule        = 'OfficeTools.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'c4b5a2ee-09e1-436c-a913-1c9d32f334d5'
    Author            = 'Shuma'
    Description       = 'Auto-generated module manifest.'

    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    RequiredAssemblies = @('$ModuleRoot\lib\HtmlAgilityPack.dll', '$ModuleRoot\lib\MailKit.dll', '$ModuleRoot\lib\MimeKit.dll')

    PrivateData = @{
        PSData = @{
            Tags         = @('Automation', 'Generated')
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = ''
        }
    }
}
