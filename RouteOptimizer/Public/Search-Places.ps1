function Search-Places {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Keyword
    )

    begin {
        try {
            Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
        }
        catch {}
    }

    process {
        try {
            $encodedKeyword = [System.Web.HttpUtility]::UrlEncode($Keyword)
            $headers = @{ "User-Agent" = "PowerShell-Geocoding-Script" }
            $uri = "https://nominatim.openstreetmap.org/search?q=$encodedKeyword&format=json&addressdetails=1&countrycodes=jp"

            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop

            if ($null -ne $response -and $response.Count -gt 0) {
                $trkptNodes = @()
                $timestamp = (Get-Date).ToString("o")

                foreach ($item in $response) {
                    $lat = [double]$item.lat
                    $lon = [double]$item.lon
                    $display = $item.display_name
                    $addr = $item.address

                    # 町名抽出（優先順：quarter > neighbourhood > suburb）
                    $townArea = $addr.quarter ?? $addr.neighbourhood ?? $addr.suburb ?? $null
                    $municipality = $addr.city ?? $addr.town ?? $addr.village ?? $null
                    $county = $addr.county
                    $suburb = $addr.suburb

                    # townname生成ロジック
                    if ($municipality -and $townArea) {
                        if ($addr.city -and $suburb) {
                            $townname = "$municipality$suburb$townArea"
                        }
                        elseif ($addr.town -and $county) {
                            $townname = "$county$municipality$townArea"
                        }
                        else {
                            $townname = "$municipality$townArea"
                        }
                    }
                    elseif ($municipality -and -not $townArea) {
                        if ($county) {
                            $townname = "$county$municipality"
                        }
                        else {
                            $townname = "$municipality"
                        }
                    }
                    else {
                        $townname = "Unknown"
                    }

                    # GPXノード構築
                    $doc = New-Object System.Xml.XmlDocument
                    $trkpt = $doc.CreateElement("trkpt")
                    $trkpt.SetAttribute("lat", $lat.ToString())
                    $trkpt.SetAttribute("lon", $lon.ToString())

                    $nameNode = $doc.CreateElement("name")
                    $nameNode.InnerText = $item.name ?? $display
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

                    $townNode = $doc.CreateElement("townname")
                    $townNode.InnerText = $townname
                    $extNode.AppendChild($townNode) | Out-Null

                    $kwNode = $doc.CreateElement("keyword")
                    $kwNode.InnerText = $Keyword
                    $extNode.AppendChild($kwNode) | Out-Null

                    $tsNode = $doc.CreateElement("timestamp")
                    $tsNode.InnerText = $timestamp
                    $extNode.AppendChild($tsNode) | Out-Null

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