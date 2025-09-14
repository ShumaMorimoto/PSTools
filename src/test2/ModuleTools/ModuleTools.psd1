@{
    RootModule        = 'ModuleTools.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '349918b4-dc13-4be8-9c4b-b595b53aee6c'
    Author            = 'Shuma'
    Description       = 'Auto-generated module manifest.'

    FunctionsToExport = @('Convert-PsmToModule', 'Get-ClassDependencyTree', 'New-Module', 'New-ModuleScaffold')
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
