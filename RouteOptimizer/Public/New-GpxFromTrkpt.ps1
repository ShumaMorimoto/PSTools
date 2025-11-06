function New-GpxFromTrkpt {
    param (
        [System.Xml.XmlElement[]]$TrkptNodes = $null,
        [string]$TrackName = "Generated Track",
        [string]$TrackDescription,
        [double]$TotalDistanceKm,
        [int]$PointCount

    )

    $xml = [xml]::new()
    $xml.AppendChild($xml.CreateXmlDeclaration("1.0", "UTF-8", $null)) | Out-Null

    $gpx = $xml.CreateElement("gpx")
    $gpx.SetAttribute("version", "1.1")
    $gpx.SetAttribute("creator", "PowerShell ConvertTo-Gpx")
    $gpx.SetAttribute("xmlns", "http://www.topografix.com/GPX/1/1")
    $xml.AppendChild($gpx) | Out-Null

    $metadata = $xml.CreateElement("metadata")
    $time = $xml.CreateElement("time")
    $time.InnerText = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
    $metadata.AppendChild($time) | Out-Null
    $gpx.AppendChild($metadata) | Out-Null

    $trk = $xml.CreateElement("trk")
    $gpx.AppendChild($trk) | Out-Null

    $name = $xml.CreateElement("name")
    $name.InnerText = [System.Security.SecurityElement]::Escape($TrackName)
    $trk.AppendChild($name) | Out-Null

    if ($TrackDescription) {
        $desc = $xml.CreateElement("desc")
        $desc.InnerText = [System.Security.SecurityElement]::Escape($TrackDescription)
        $trk.AppendChild($desc) | Out-Null
    }

    # extensions に統計情報を追加
    if ($TotalDistanceKm -or $PointCount) {
        $ext = $xml.CreateElement("extensions")
        $stats = $xml.CreateElement("stats")

        if ($TotalDistanceKm) {
            $distNode = $xml.CreateElement("totalDistanceKm")
            $distNode.InnerText = [string]::Format("{0:F2}", $TotalDistanceKm)
            $stats.AppendChild($distNode) | Out-Null
        }

        if ($PointCount) {
            $countNode = $xml.CreateElement("pointCount")
            $countNode.InnerText = "$PointCount"
            $stats.AppendChild($countNode) | Out-Null
        }

        $ext.AppendChild($stats) | Out-Null
        $trk.AppendChild($ext) | Out-Null
    }

    $trkseg = $xml.CreateElement("trkseg")
    $trk.AppendChild($trkseg) | Out-Null

    foreach ($node in $TrkptNodes) {
        $imported = $xml.ImportNode($node, $true)
        $trkseg.AppendChild($imported) | Out-Null
    }

    return $xml
}