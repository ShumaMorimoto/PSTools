Import-Module $PSScriptRoot\RouteOptimizer.psm1

$filename = "D:\tool\Repository\PSTools\tool\GPX\都市\岐阜県_恵那市_towns.gpx"
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
$bestRoute = Optimize-Route -Places $places -PopulationSize 100 -Generations 10


#Start-RouteAnimation -Places $places -Generations 200

