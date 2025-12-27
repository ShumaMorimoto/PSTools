using module D:\tool\Repository\PSTools\RouteOptimizer
using module D:\tool\Repository\PSTools\GPXTools

$towns = [GPXDocumentFactory]::FromCItyTOwns("葉山町", $false)
$pso = $towns.GetTrkPts() | ForEach-Object { [GPXDocument]::ElementToPSO($_) }

$moduleRoot = (Get-Module GPXTools | Select-Object -First 1).ModuleBase

Start-Optimizer -Page (Join-Path $moduleRoot "data\sample.html") -PSO $pso

