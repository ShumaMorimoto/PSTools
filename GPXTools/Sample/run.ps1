#using module D:\tool\Repository\PSTools\GPXTools
using module D:\tool\Repository\PSTools\GPXTools

#$towns = [GpxService]::FromCityTowns("横須賀市")
#$pso = $towns.GetTrkpts()

$pso = $null
Start-Optimizer -Page D:\tool\Repository\PSTools\GPXTools\data\map.html -PSO $pso

