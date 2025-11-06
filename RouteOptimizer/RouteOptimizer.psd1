@{
    RootModule         = 'RouteOptimizer.psm1'
    ModuleVersion      = '1.0.3'
    GUID               = '9d7ee62e-61c3-498b-ae57-fd1fd8eab36b'
    Author             = ''
    Description        = ''

    FunctionsToExport  = @('ConvertFrom-Gpx', 'ConvertTo-Gpx', 'ConvertTo-GpxFromPoints', 'Add-GpxStats',
                            'New-GpxFromTrkpt', 'Split-Gpx', 'Get-CityTowns',
                            'Optimize-Route', 'Optimize-Route2', 'Start-RouteAnimation')
    CmdletsToExport    = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    RequiredAssemblies = @()

    PrivateData        = @{
        PSData = @{
            Tags         = @('Automation', 'Generated')
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = ''
        }
    }
}
