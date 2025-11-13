@{
    RootModule        = 'RouteOptimizer.psm1'
    ModuleVersion     = '1.0.6'
    GUID              = '9d7ee62e-61c3-498b-ae57-fd1fd8eab36b'
    Author            = ''
    Description       = ''

    FunctionsToExport = @(@(
    'Add-GpxStats',
    'ConvertFrom-Gpx',
    'ConvertTo-Gpx',
    'ConvertTo-GpxFromPoints',
    'Get-CityTowns',
    'Get-Place',
    'Group-Places',
    'New-GpxFromTrkpt',
    'Optimize-AreaRoute',
    'Optimize-Route',
    'Search-Place',
    'Show-Groups',
    'Split-Route'
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
