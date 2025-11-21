Import-Module $PSScriptRoot\RouteOptimizer.psm1

$filename = "D:\tool\Repository\PSTools\tool\GPX\都市\石川県_金沢市_towns.gpx"
$newfilename =   "D:\tool\tmp\optimized.gpx"

$places = @()
$item = Get-Item $filename

if ($item.Extension -ieq ".kml") {
    $newName = "【GA】" + $item.BaseName + ".gpx"
    $newFullPath = Join-Path $item.DirectoryName $newName
    $places = Import-KmlPlaces -KmlPath $item
} else {
    $newName = "【GA】" + $item.Name
    $newFullPath = Join-Path $item.DirectoryName $newName
    $places = Import-GpxPlaces -GpxPath $item
}

# 最適化
#$bestRoute = Optimize-Route2 -Places $places -PopulationSize 50 -Generations 100 -FitnessFunction ${function:Get-Fitness}

$bestRoute = Optimize-Route -Places $places -PopulationSize 100 -Generations 1000

# GPX出力
Export-GpxRoute -Route $bestRoute -OutputPath $newFullPath
