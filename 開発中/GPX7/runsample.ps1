using module D:\tool\Repository\PSTools\RouteOptimizer
using module D:\tool\Repository\PSTools\GPXTools


#$towns = [GPXDocumentFactory]::FromCityTowns("葉山町")
#$pso = [GPXDocument]::ElementToPSO($towns.documentElement)

$pso = $null

Start-Optimizer -Page D:\tool\Repository\PSTools\開発中\GPX7\map.html -PSO $pso

