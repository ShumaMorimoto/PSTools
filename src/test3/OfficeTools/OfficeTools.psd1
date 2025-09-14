@{
    RootModule        = '{{ModuleName}}.psm1'
    ModuleVersion     = '1.0.4'
    GUID              = '4cf244cb-97f6-432e-b7b3-0a2be45b8215'
    Author            = ''
    Description       = ''

    FunctionsToExport = @({{ExportFunctions}})
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    RequiredAssemblies = @('HtmlAgilityPack.dll', 'MailKit.dll', 'MimeKit.dll')

    PrivateData = @{
        PSData = @{
            Tags         = @('Automation', 'Generated')
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = ''
        }
    }
}
