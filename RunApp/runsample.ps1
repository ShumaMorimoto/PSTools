using module D:\tool\Repository\PSTools\RouteOptimizer
using module D:\tool\Repository\PSTools\RunApp

$DummyLogic = {
    param($State, $data)
    Write-Host "[DummyLogic] Start"
    for ($i = 1; $i -le 10; $i++) {

        if ($State.Stop) {
            Write-Host "[DummyLogic] Stop requested"
            break
        }
        $State.Generation = $i
        $State.UpdatedAt = Get-Date
        $State.BestDist = 1000 - ($i * 10)
        $State.BestRoute = @(0, 1, 2, 3)

        Write-Host "[DummyLogic] Generation $i"
        Start-Sleep -Milliseconds 300
    }
    Write-Host "[DummyLogic] Finished"
}

$DummyRoutes = @{
    Start   = {
        param($data, $rh)
        $rh.Start($data)
    }
    Stop    = {
        param($data, $rh)
        $rh.Stop()
    }
    Status  = {
        param($data, $rh)
        @{
            Generation = $rh.State.Generation
            UpdatedAt  = $rh.State.UpdatedAt
            BestDist   = $rh.State.BestDist
        }
    }
    GetBest = {
        param($data, $rh)
        $rh.State.BestRoute | ForEach-Object {
            $rh.State.Places[$_]
        }
    }
    Optimize    = {
        
        param($data, $rh)
        Optimize-AreaRoute $data
    }
}

$towns = [GPXDocumentFactory]::FromCItyTOwns("葉山町", $false)
$pso = $towns.GetTrkPts() | ForEach-Object { [GPXDocument]::ElementToPSO($_) }

#Run-App -StartScript $DummyLogic -Routes $DummyRoutes -PageName D:\tool\Repository\PSTools\開発中\GPX4\map.html -InitialData $pso

Run-App -StartScript $DummyLogic -Routes $DummyRoutes -PageName D:\tool\Repository\PSTools\RunApp\lib\sample.html -InitialData $pso
