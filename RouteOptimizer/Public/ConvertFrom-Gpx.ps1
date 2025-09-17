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
