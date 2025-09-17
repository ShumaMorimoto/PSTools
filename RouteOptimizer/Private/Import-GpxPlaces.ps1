function Import-GpxPlaces {
    param (
        [string]$GpxPath
    )
    [xml]$gpx = Get-Content $GpxPath

    $wpts = $gpx.gpx.trk.trkseg.trkpt
    $places = @()
    foreach ($wpt in $wpts) {
        $name = $wpt.name
        $lat = [double]$wpt.lat
        $lon = [double]$wpt.lon
        $places += @{ Name = $name; Lat = $lat; Lon = $lon }
    }
    $places = Remove-DuplicatePlaces -Places $places
    return $places
}
