function Invoke-FromCityTowns {
    param(
        $InputData
    )
    $towns = [GPXService]::FromCityTowns($InputData)
    return $towns
}