using module D:\tool\Repository\PSTools\GPXTools

#$towns = [GpxService]::FromCityTowns("横須賀市")
#$pso = $towns.GetTrkpts()
#$pso = $null
#Start-Optimizer -Page D:\tool\Repository\PSTools\GPXTools\data\map.html -PSO $pso

# 名前またはパスで呼び出し
#               -PublicPath "D:\tool\Repository\PSTools\開発中\GPX7"

$path = resolve-path (join-path $PSScriptRoot "..\data" )
Start-PodeHost -ModuleName "GPXTools" 
               -PublicPath $path

#$path = join-path $PSScriptRoot "..\data" 

