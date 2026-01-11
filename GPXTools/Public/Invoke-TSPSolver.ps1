function Invoke-TSPSolver {
    param(
        $InputData
    )
    $State = Run-TSPSolver -Places $InputData -State @{}
    return $State.Result.Route
}