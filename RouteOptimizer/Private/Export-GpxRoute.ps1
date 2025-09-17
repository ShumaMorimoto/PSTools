function Export-GpxRoute {
    param (
        [array]$Route,
        [string]$OutputPath
    )
    $Route += $Route[0]
    $gpxXml = New-Object System.Xml.XmlDocument
    $gpxXml.AppendChild($gpxXml.CreateXmlDeclaration("1.0", "UTF-8", $null)) | Out-Null

    $gpxElem = $gpxXml.CreateElement("gpx")
    $gpxElem.SetAttribute("version", "1.1")
    $gpxElem.SetAttribute("creator", "RouteOptimizer")
    $gpxElem.SetAttribute("xmlns", "http://www.topografix.com/GPX/1/1")
    $gpxXml.AppendChild($gpxElem) | Out-Null

    $trkElem = $gpxXml.CreateElement("trk")
    $trksegElem = $gpxXml.CreateElement("trkseg")

    foreach ($pt in $Route) {
        $trkpt = $gpxXml.CreateElement("trkpt")
        $trkpt.SetAttribute("lat", "$($pt.Lat)")
        $trkpt.SetAttribute("lon", "$($pt.Lon)")

        if ($pt.Name) {
            $nameElem = $gpxXml.CreateElement("name")
            $nameElem.InnerText = $pt.Name
            $trkpt.AppendChild($nameElem) | Out-Null
        }

        $trksegElem.AppendChild($trkpt) | Out-Null
    }

    $trkElem.AppendChild($trksegElem) | Out-Null
    $gpxElem.AppendChild($trkElem) | Out-Null

    $gpxXml.Save($OutputPath)
    Write-Host "✅ GPXルートを保存しました: $OutputPath"
}
