function Get-Place {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [double]$Latitude,

        [Parameter(Mandatory)]
        [double]$Longitude
    )

    $headers = @{ "User-Agent" = "PowerShell-ReverseGeocoding" }
    $uri = "https://nominatim.openstreetmap.org/reverse?lat=$Latitude&lon=$Longitude&format=json&addressdetails=1"

    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop
        $addr = $response.address
        $display = $response.display_name

        # 町字（優先順）
        $townArea = $addr.road ?? $addr.suburb ?? $addr.neighbourhood ?? $addr.city ?? 'Unknown'

        # GPXノード構築
        $doc = New-Object System.Xml.XmlDocument
        $trkpt = $doc.CreateElement("trkpt")
        $trkpt.SetAttribute("lat", $Latitude.ToString())
        $trkpt.SetAttribute("lon", $Longitude.ToString())

        $nameNode = $doc.CreateElement("name")
        $nameNode.InnerText = $townArea
        $trkpt.AppendChild($nameNode) | Out-Null

        $descNode = $doc.CreateElement("desc")
        $descNode.InnerText = $display
        $trkpt.AppendChild($descNode) | Out-Null

        $extNode = $doc.CreateElement("extensions")
        foreach ($key in $addr.PSObject.Properties.Name) {
            $val = $addr.$key
            if ($val) {
                $child = $doc.CreateElement($key)
                $child.InnerText = $val
                $extNode.AppendChild($child) | Out-Null
            }
        }
        $trkpt.AppendChild($extNode) | Out-Null

        return $trkpt
    }
    catch {
        Write-Error "逆ジオコーディングに失敗しました: $($_.Exception.Message)"
        return $null
    }
}