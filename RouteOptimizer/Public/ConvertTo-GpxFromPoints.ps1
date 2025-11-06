function ConvertTo-GpxFromPoints {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$InputObject,

        [Parameter()]
        [string]$TrackName = "PowerShell Exported Track",

        [Parameter()]
        [string]$TrackDescription
    )

    Begin {
        $points = [System.Collections.Generic.List[object]]::new()
    }

    Process {
        foreach ($item in $InputObject) {
            $points.Add($item)
        }
    }

    End {
        if ($points.Count -eq 0) {
            Write-Warning "入力オブジェクトがありません。XMLは生成されませんでした。"
            return
        }

        # 空のGPX XMLを生成（trksegノードを含む）
        $xml = New-GpxFromTrkpt -TrackName $TrackName -TrackDescription $TrackDescription
        $trkseg = $xml.gpx.trk.trkseg

        foreach ($point in $points) {
            $lat = $point.lat ?? $point.latitude
            $lon = $point.lon ?? $point.longitude
            if ($null -eq $lat -or $null -eq $lon) {
                Write-Warning "緯度または経度が不足しているためスキップ: $($point | Out-String)"
                continue
            }

            $trkpt = $xml.CreateElement("trkpt")
            $trkpt.SetAttribute("lat", "$lat")
            $trkpt.SetAttribute("lon", "$lon")
            $trkpt.SetAttribute("muitiRoute", "1")

            if ($point.ele ?? $point.elevation) {
                $eleNode = $xml.CreateElement("ele")
                $eleNode.InnerText = "$($point.ele ?? $point.elevation)"
                $trkpt.AppendChild($eleNode) | Out-Null
            }

            if ($point.time) {
                $timeStr = ($point.time -is [datetime]) ? $point.time.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'") : "$($point.time)"
                $timeNode = $xml.CreateElement("time")
                $timeNode.InnerText = $timeStr
                $trkpt.AppendChild($timeNode) | Out-Null
            }

            if ($point.tags.name) {
                $nameNode = $xml.CreateElement("name")
                $nameNode.InnerText = [System.Security.SecurityElement]::Escape($point.tags.name)
                $trkpt.AppendChild($nameNode) | Out-Null
            }

            $trkseg.AppendChild($trkpt) | Out-Null
        }

        return $xml
    }
}