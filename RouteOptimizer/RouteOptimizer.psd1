@{
    RootModule        = 'RouteOptimizer.psm1'
    ModuleVersion     = '1.0.8'
    GUID              = '9d7ee62e-61c3-498b-ae57-fd1fd8eab36b'
    Author            = ''
    Description       = ''

    FunctionsToExport = @(@(
    'Get-CityTowns',
    'Get-PlaceInfo',
    'Get-TownsAround',
    'Group-Places',
    'Optimize-AreaRoute',
    'Optimize-Route',
    'Search-Places',
    'Show-Groups',
    'Split-Places',
    'Select-Places'
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
