function Search-Place {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Keyword
    )

    begin {
        try {
            Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
        } catch {}
    }

    process {
        try {
            $encodedKeyword = [System.Web.HttpUtility]::UrlEncode($Keyword)
            $headers = @{ "User-Agent" = "PowerShell-Geocoding-Script" }
            $uri = "https://nominatim.openstreetmap.org/search?q=$encodedKeyword&format=json&addressdetails=1"

            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop

            if ($null -ne $response -and $response.Count -gt 0) {
                $trkptNodes = @()

                foreach ($item in $response) {
                    $lat = [double]$item.lat
                    $lon = [double]$item.lon
                    $display = $item.display_name
                    $addr = $item.address

                    # 町字（優先順：road > suburb > neighbourhood > city）
                    $townArea = $addr.road ?? $addr.suburb ?? $addr.neighbourhood ?? $addr.city ?? 'Unknown'

                    # GPXノード構築
                    $doc = New-Object System.Xml.XmlDocument
                    $trkpt = $doc.CreateElement("trkpt")
                    $trkpt.SetAttribute("lat", $lat.ToString())
                    $trkpt.SetAttribute("lon", $lon.ToString())

                    # <name> = 町字
                    $nameNode = $doc.CreateElement("name")
                    $nameNode.InnerText = $townArea
                    $trkpt.AppendChild($nameNode) | Out-Null

                    # <desc> = display_name
                    $descNode = $doc.CreateElement("desc")
                    $descNode.InnerText = $display
                    $trkpt.AppendChild($descNode) | Out-Null

                    # <extensions> に address を埋め込む
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

                    $trkptNodes += $trkpt
                }

                return $trkptNodes
            }
            else {
                Write-Warning "キーワード '$Keyword' に一致する結果が見つかりませんでした。"
                return @()
            }
        }
        catch {
            Write-Error "キーワード '$Keyword' の処理中にエラーが発生しました: $($_.Exception.Message)"
            return @()
        }
    }
}