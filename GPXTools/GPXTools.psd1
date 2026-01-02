@{
    RootModule        = 'GPXTools.psm1'
    ModuleVersion     = '1.0.8'
    GUID              = '7449eb72-43ab-4e96-9e04-346e379d3e2e'
    Author            = ''
    Description       = ''

    FunctionsToExport = @(@(
    'Cluster-KMeans',
    'Cluster-Mesh',
    'Run-CTSPSolver',
    'Run-GASimulation',
    'Run-TSPSolver',
    'Start-Optimizer',
    'Test-GASimulation'
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
