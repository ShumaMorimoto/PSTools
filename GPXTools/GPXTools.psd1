@{
    RootModule        = 'GPXTools.psm1'
    ModuleVersion     = '1.0.13'
    GUID              = '7449eb72-43ab-4e96-9e04-346e379d3e2e'
    Author            = ''
    Description       = ''

    FunctionsToExport = @(@(
    'Cluster-KMeans',
    'Cluster-Mesh',
    'Invoke-FromCityTowns',
    'Invoke-KMeansCluster',
    'Invoke-TSPSolver',
    'Run-CTSPSolver',
    'Run-TSPSolver',
    'Start-PodeHost',
    'Update-GpxAddressMetadata'
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
