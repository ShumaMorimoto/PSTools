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
            if ($point.name) {
                $nameNodePt = $xml.CreateElement("name")
                # XML特殊文字をエスケープ
                $nameNodePt.InnerText = [System.Security.SecurityElement]::Escape($point.name)
                $trkptNode.AppendChild($nameNodePt) | Out-Null
            }
            
            $trksegNode.AppendChild($trkptNode) | Out-Null
        }

        Write-Output $xml
    }
}

function ConvertFrom-Gpx {
    <#
    .SYNOPSIS
        GPX形式のXMLオブジェクトまたは文字列を、ハッシュテーブルの配列に変換します。

    .DESCRIPTION
        GPX形式のXMLデータ内の全てのトラックポイント(<trkpt>)を抽出し、
        lat, lon, およびオプションで ele, time, name を含むハッシュテーブルの配列として出力します。

    .PARAMETER InputObject
        変換するGPXデータ ([System.Xml.XmlDocument]オブジェクトまたはXML形式の文字列)。

    .EXAMPLE
        PS C:\> $gpxXml = Get-Content -Path "C:\temp\MyTrack.gpx" -Raw
        PS C:\> $gpxXml | ConvertFrom-Gpx

    .OUTPUTS
        [System.Collections.Hashtable[]]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject
    )

    process {
        [xml]$gpxContent = $null

        if ($InputObject -is [System.Xml.XmlNode]) {
            $gpxContent = $InputObject
        }
        elseif ($InputObject -is [string]) {
            try {
                $gpxContent = [xml]$InputObject
            }
            catch {
                Write-Error "入力された文字列のXML解析に失敗しました。有効なXMLではありません。 詳細: $($_.Exception.Message)"
                return
            }
        }
        else {
            Write-Error "サポートされていない入力タイプです: '$($InputObject.GetType().FullName)'。 [xml]オブジェクトまたはXML形式の文字列を指定してください。"
            return
        }

        $ns = [System.Xml.XmlNamespaceManager]::new($gpxContent.NameTable)
        $ns.AddNamespace("gpx", "http://www.topografix.com/GPX/1/1")

        $trackPoints = $gpxContent.SelectNodes("//gpx:trkpt", $ns)

        if ($null -eq $trackPoints -or $trackPoints.Count -eq 0) {
            Write-Warning "指定されたXMLデータ内にトラックポイント(<trkpt>)が見つかりませんでした。"
            return
        }

        foreach ($point in $trackPoints) {
            $lat = $point.GetAttribute("lat")
            $lon = $point.GetAttribute("lon")

            if ([string]::IsNullOrEmpty($lat) -or [string]::IsNullOrEmpty($lon)) {
                Write-Warning "緯度または経度属性がない<trkpt>をスキップしました。"
                continue
            }

            $outputObject = [ordered]@{
                lat = [double]$lat
                lon = [double]$lon
            }

            $eleNode = $point.SelectSingleNode("gpx:ele", $ns)
            if ($null -ne $eleNode) {
                $outputObject.ele = [double]$eleNode.InnerText
            }

            $timeNode = $point.SelectSingleNode("gpx:time", $ns)
            if ($null -ne $timeNode) {
                try {
                    $outputObject.time = [datetime]::Parse($timeNode.InnerText, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
                }
                catch {
                    Write-Warning "時刻 '$($timeNode.InnerText)' の解析に失敗しました。文字列として格納します。"
                    $outputObject.time = $timeNode.InnerText
                }
            }
            
            # <name> (トラックポイントの名前) を取得
            $nameNode = $point.SelectSingleNode("gpx:name", $ns)
            if ($null -ne $nameNode) {
                $outputObject.name = $nameNode.InnerText
            }

            Write-Output $outputObject
        }
    }
}
