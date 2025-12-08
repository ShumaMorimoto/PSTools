@{
    RootModule        = 'GUITools.psm1'
    ModuleVersion     = '1.0.8'
    GUID              = 'ab2a5c2b-3def-4650-b9a2-9249742e9184'
    Author            = ''
    Description       = ''

    FunctionsToExport = @(@(
    'Add-History',
    'Convert-EntryToItem',
    'Get-GUIToolsControl',
    'Get-GUIToolsWindow',
    'Get-History',
    'Init-DetailGridLogic',
    'Init-ResultGridLogic',
    'Init-SearchComboLogic',
    'Load-History',
    'New-UIElement',
    'Refresh-List',
    'Save-History'
))
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    RequiredAssemblies = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Automation', 'Generated')
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = ''
        }
    }
}
