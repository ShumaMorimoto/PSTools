function Get-Distance {
    param($p1, $p2)
    $R = 6371
    $dLat = [math]::PI / 180 * ($p2.lat - $p1.lat)
    $dLon = [math]::PI / 180 * ($p2.lon - $p1.lon)
    $lat1 = [math]::PI / 180 * $p1.lat; $lat2 = [math]::PI / 180 * $p2.lat
    $a = [math]::Pow([math]::Sin($dLat / 2), 2) + [math]::Cos($lat1) * [math]::Cos($lat2) * [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}
