function ConvertTo-Gpx {
    <#
    .SYNOPSIS
        ハッシュテーブルの配列からGPX形式のXMLオブジェクトを生成します。

    .DESCRIPTION
        緯度(lat)と経度(lon)を含むハッシュテーブルの配列を、GPX形式のXMLオブジェクトに変換します。
        各ハッシュテーブルはGPXのトラックポイント(<trkpt>)に対応します。

    .PARAMETER InputObject
        GPXトラックポイントとして変換するハッシュテーブルの配列。
        各ハッシュテーブルには、以下のキーを含める必要があります。
        - lat (または latitude): 緯度 (必須)
        - lon (または longitude): 経度 (必須)
        - ele (または elevation): 高度(メートル) (任意)
        - time: 時刻 ([DateTime]オブジェクトまたはISO8601形式の文字列) (任意)
        - name: トラックポイントの名前 (任意)
        このパラメータはパイプラインからの入力を受け付けます。

    .PARAMETER TrackName
        GPXファイル内のトラック全体の名前(<trk>の<name>タグ)。

    .PARAMETER TrackDescription
        GPXファイル内のトラックの説明(<desc>タグ)。

    .EXAMPLE
        PS C:\> $points = @(
            @{ lat = 35.3266; lon = 137.5878; name = "海" },
            @{ lat = 35.4851; lon = 137.3258; name = "笠置町河合" }
        )
        PS C:\> $points | ConvertTo-Gpx -TrackName "恵那の旅"

    .OUTPUTS
        [System.Xml.XmlDocument]
    #>
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

        $xml = [System.Xml.XmlDocument]::new()
        $xml.AppendChild($xml.CreateXmlDeclaration("1.0", "UTF-8", $null)) | Out-Null

        $gpxNode = $xml.CreateElement("gpx")
        $gpxNode.SetAttribute("version", "1.1")
        $gpxNode.SetAttribute("creator", "PowerShell ConvertTo-Gpx")
        $gpxNode.SetAttribute("xmlns", "http://www.topografix.com/GPX/1/1")
        $xml.AppendChild($gpxNode) | Out-Null

        $metadataNode = $xml.CreateElement("metadata")
        $timeNode = $xml.CreateElement("time")
        $timeNode.InnerText = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
        $metadataNode.AppendChild($timeNode) | Out-Null
        $gpxNode.AppendChild($metadataNode) | Out-Null

        $trkNode = $xml.CreateElement("trk")
        $gpxNode.AppendChild($trkNode) | Out-Null
        
        $nameNode = $xml.CreateElement("name")
        $nameNode.InnerText = [System.Security.SecurityElement]::Escape($TrackName)
        $trkNode.AppendChild($nameNode) | Out-Null
        
        if ($TrackDescription) {
            $descNode = $xml.CreateElement("desc")
            $descNode.InnerText = [System.Security.SecurityElement]::Escape($TrackDescription)
            $trkNode.AppendChild($descNode) | Out-Null
        }

        $trksegNode = $xml.CreateElement("trkseg")
        $trkNode.AppendChild($trksegNode) | Out-Null

        foreach ($point in $points) {
            $lat = $point.lat ?? $point.latitude
            $lon = $point.lon ?? $point.longitude

            if ($null -eq $lat -or $null -eq $lon) {
                Write-Warning "緯度(lat/latitude)または経度(lon/longitude)がありません。このポイントはスキップされます: $($point | Out-String)"
                continue
            }

            $trkptNode = $xml.CreateElement("trkpt")
            $trkptNode.SetAttribute("lat", ([string]$lat))
            $trkptNode.SetAttribute("lon", ([string]$lon))
            $trkptNode.SetAttribute("muitiRoute", "1")  # デフォルト属性追加

            $ele = $point.ele ?? $point.elevation
            if ($null -ne $ele) {
                $eleNode = $xml.CreateElement("ele")
                $eleNode.InnerText = [string]$ele
                $trkptNode.AppendChild($eleNode) | Out-Null
            }

            if ($point.time) {
                $timeValue = $point.time
                if ($timeValue -is [DateTime]) {
                    $timeString = $timeValue.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                }
                else {
                    $timeString = [string]$timeValue
                }
                $timeNodePt = $xml.CreateElement("time")
                $timeNodePt.InnerText = $timeString
                $trkptNode.AppendChild($timeNodePt) | Out-Null
            }
            
            # <name> (トラックポイントの名前)
            if ($point.tags.name) {
                $nameNodePt = $xml.CreateElement("name")
                # XML特殊文字をエスケープ
                $nameNodePt.InnerText = [System.Security.SecurityElement]::Escape($point.tags.name)
                $trkptNode.AppendChild($nameNodePt) | Out-Null
            }
            
            $trksegNode.AppendChild($trkptNode) | Out-Null
        }

        Write-Output $xml
    }
}
