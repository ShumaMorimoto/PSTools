using module D:\tool\Repository\PSTools\RouteOptimizer
using module D:\tool\Repository\PSTools\GPXTools


#$towns = [GPXDocumentFactory]::FromCityTowns("葉山町")
#$pso = [GPXDocument]::ElementToPSO($towns.documentElement)

Start-Optimizer -Page D:\tool\Repository\PSTools\開発中\GPX4\map.html -PSO $pso

