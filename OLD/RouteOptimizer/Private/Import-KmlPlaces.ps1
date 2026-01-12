function Import-KmlPlaces {
    param (
        [string]$KmlPath
    )

    [xml]$kml = Get-Content $KmlPath
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($kml.NameTable)
    $nsMgr.AddNamespace("kml", "http://www.opengis.net/kml/2.2")

    $placemarks = $kml.SelectNodes("//kml:Placemark", $nsMgr)
    $places = @()
    foreach ($pm in $placemarks) {
        $name = $pm.name
        $coordText = $pm.Point.coordinates
        if ($coordText) {
            $parts = $coordText -split ","
            $lon = [double]$parts[0]
            $lat = [double]$parts[1]
            $places += @{ Name = $name; Lat = $lat; Lon = $lon }
        }
    }
    $places = Remove-DuplicatePlaces -Places $places
    return $places
}
