using module D:\tool\Repository\PSTools\GPXTools

$towns = [GPXService]::FromCItyTOwns("横須賀市")
$pso = $towns.GetTrkpts()

$moduleRoot = (Get-Module GPXTools | Select-Object -First 1).ModuleBase

Start-Optimizer -Page (Join-Path $moduleRoot "data\sample.html") -PSO $pso

