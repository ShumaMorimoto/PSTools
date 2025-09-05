Import-Module $PSScriptRoot\RouteOptimizer.psm1

$filename = "C:\Program Files (x86)\iMyFone\iMyFone AnyTo\AnyTo Route\その他\大阪茶屋オリジナル.gpx"
$newfilename =   "H:\tool\tmp\optimized.gpx"

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
#$bestRoute = Optimize-Route -Places $places -PopulationSize 100 -Generations 200
$bestRoute = Optimize-Route2 -Places $places -PopulationSize 50 -Generations 100 -FitnessFunction ${function:Get-Fitness}

# GPX出力
#Export-GpxRoute -Route $bestRoute -OutputPath $newFullPath
