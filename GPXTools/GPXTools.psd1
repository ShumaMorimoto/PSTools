@{
    RootModule        = 'GPXTools.psm1'
    ModuleVersion     = '1.0.9'
    GUID              = '7449eb72-43ab-4e96-9e04-346e379d3e2e'
    Author            = ''
    Description       = ''

    FunctionsToExport = @(@(
    'Cluster-KMeans',
    'Cluster-Mesh',
    'Invoke-KMeansCluster',
    'Invoke-TSPSolver',
    'Run-CTSPSolver',
    'Run-TSPSolver',
    'Start-Optimizer',
    'Start-PodeHost'
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
