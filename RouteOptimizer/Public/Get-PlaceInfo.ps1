function Get-PlaceInfo {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [object]$InputObject
    )

    begin {
        $headers = @{ "User-Agent" = "PowerShell-ReverseGeocoding" }
        $doc = New-Object System.Xml.XmlDocument
    }

    process {
        # lat/lon抽出（trkptノード or 任意オブジェクト対応）
        $lat = $InputObject.lat ?? $InputObject.Latitude
        $lon = $InputObject.lon ?? $InputObject.Longitude

        if (-not ($lat -and $lon)) {
            Write-Warning "緯度経度が見つかりません: $($InputObject | Out-String)"
            return
        }

        $uri = "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1"

        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop
            $addr = $response.address
            $display = $response.display_name
            $townArea = $addr.road ?? $addr.suburb ?? $addr.neighbourhood ?? $addr.city ?? 'Unknown'

            # 入力がtrkptノードならコピーして使う
            if ($InputObject -is [System.Xml.XmlElement] -and $InputObject.Name -eq "trkpt") {
                $trkpt = $doc.ImportNode($InputObject, $true)

                # name, desc, extensions をすべて削除
                foreach ($tag in @("name", "desc", "extensions")) {
                    $nodes = $trkpt.SelectNodes($tag)
                    foreach ($node in $nodes) {
                        $trkpt.RemoveChild($node) | Out-Null
                    }
                }
            }
            else {
                # 新規trkptノードを作成
                $trkpt = $doc.CreateElement("trkpt")
                $trkpt.SetAttribute("lat", $lat.ToString())
                $trkpt.SetAttribute("lon", $lon.ToString())
            }

            # nameノード
            $nameNode = $doc.CreateElement("name")
            $nameNode.InnerText = $townArea
            $trkpt.AppendChild($nameNode) | Out-Null

            # descノード
            $descNode = $doc.CreateElement("desc")
            $descNode.InnerText = $display
            $trkpt.AppendChild($descNode) | Out-Null

            # extensionsノード
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
            Write-Warning "[$lat,$lon] 逆ジオコーディング失敗: $($_.Exception.Message)"
        }
    }
}