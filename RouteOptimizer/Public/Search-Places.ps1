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
                # GPXDocumentを生成
                $doc = [GPXDocument]::new("Search-Places",$Keyword)
                $timestamp = (Get-Date).ToString("o")

                foreach ($item in $response) {
                    $lat   = [double]$item.lat
                    $lon   = [double]$item.lon
                    $display = $item.display_name
                    $addr  = $item.address

                    # 町名抽出（優先順：quarter > neighbourhood > suburb）
                    $townArea     = $addr.quarter ?? $addr.neighbourhood ?? $addr.suburb ?? $null
                    $municipality = $addr.city ?? $addr.town ?? $addr.village ?? $null
                    $county       = $addr.county
                    $suburb       = $addr.suburb

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

                    # 住所情報に追加フィールドを付与
                    $addrExt = $addr.PSObject.Copy()
                    $addrExt | Add-Member -NotePropertyName "townname" -NotePropertyValue $townname
                    $addrExt | Add-Member -NotePropertyName "keyword"  -NotePropertyValue $Keyword
                    $addrExt | Add-Member -NotePropertyName "timestamp" -NotePropertyValue $timestamp

                    # GPXDocumentのメソッドでtrkpt追加
                    $doc.AddTrkPt($lat, $lon, ($item.name ?? $display), $display, $addrExt)
                }

                # 統計情報も追加
                $doc.UpdateStats()

                return [GPXDocument]$doc
            }
            else {
                Write-Warning "キーワード '$Keyword' に一致する結果が見つかりませんでした。"
                return $null
            }
        }
        catch {
            Write-Error "キーワード '$Keyword' の処理中にエラーが発生しました: $($_.Exception.Message)"
            return $null
        }
    }
}