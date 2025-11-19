function Remove-DuplicatePlaces {
    param (
        [array]$Places
    )

    $unique = @{}
    $result = @()

    foreach ($pt in $Places) {
        $key = "$($pt.Lat),$($pt.Lon)"
        if (-not $unique.ContainsKey($key)) {
            $unique[$key] = $true
            $result += $pt
        }
    }

    return $result
}
