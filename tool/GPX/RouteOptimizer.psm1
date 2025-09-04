# 距離計算（Haversine）
function Get-Distance($p1, $p2) {
    $R = 6371 # 地球半径 km
    $dLat = [math]::PI / 180 * ($p2.Lat - $p1.Lat)
    $dLon = [math]::PI / 180 * ($p2.Lon - $p1.Lon)
    $lat1 = [math]::PI / 180 * $p1.Lat
    $lat2 = [math]::PI / 180 * $p2.Lat

    $a = [math]::Pow([math]::Sin($dLat / 2), 2) + [math]::Cos($lat1) * [math]::Cos($lat2) * [math]::Pow([math]::Sin($dLon / 2), 2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
    return $R * $c
}

function Get-TotalDistance($route) {
    $sum = 0
    for ($i = 0; $i -lt $route.Count - 1; $i++) {
        $sum += Get-Distance $route[$i] $route[$i + 1]
    }
    $sum += Get-Distance $route[-1] $route[0]
    return $sum
}

function Get-RandomRoute($places) {
    return $places | Sort-Object { Get-Random }
}

function Mutate($route) {
    # ディープコピー（新しい place オブジェクトを作る）
    $newRoute = @()
    foreach ($pt in $route) {
        $newRoute += , @{ Name = $pt.Name; Lat = $pt.Lat; Lon = $pt.Lon }
    }

    # ランダムに2点を入れ替える
    do {
        $i = Get-Random -Minimum 0 -Maximum $newRoute.Count
        $j = Get-Random -Minimum 0 -Maximum $newRoute.Count
    } while ($i -eq $j)

    $temp = $newRoute[$i]
    $newRoute[$i] = $newRoute[$j]
    $newRoute[$j] = $temp

    return $newRoute
}
function Optimize-Route {
    param (
        [array]$Places,
        [int]$PopulationSize = 50,
        [int]$Generations = 100
    )

    $population = @()
    for ($i = 0; $i -lt $PopulationSize; $i++) {
        $population += , (Get-RandomRoute $Places)
    }

    for ($gen = 0; $gen -lt $Generations; $gen++) {
        $population = $population | Sort-Object { Get-TotalDistance $_ }
        $best = $population[0]

        if (-not $best -or $best.Count -lt 2) {
            Write-Warning "⚠️ 世代 $gen で異常な個体が検出されました。"
            break
        }

        $distance = Get-TotalDistance $best
        Write-Host "世代 $gen - 最短距離: $([math]::Round($distance, 2)) km"
        #        Write-Host "ルート: " + ($best | ForEach-Object { $_.Name }) -join " → "
        #        Write-Host ""

        $newPopulation = @()
        $newPopulation += , $best

        while ($newPopulation.Count -lt $PopulationSize) {
            $parent = $population[(Get-Random -Minimum 0 -Maximum 10)]
            $child = Mutate $parent
            if ($child.Count -eq $Places.Count) {
                $newPopulation += , $child
            }
        }

        $population = $newPopulation
    }

    return $best
}
Export-ModuleMember -Function Get-Distance, Get-TotalDistance, Get-RandomRoute, Mutate, Optimize-Route
function Remove-DuplicatePlaces {
    param (
        [array]$Places
    )

    $unique = @{}
    $result = @()

    foreach ($pt in $Places) {
        $key = "$($pt.Lat),$($pt.Lon)"
        if (-not $unique.ContainsKey($key)) {
            $unique[$key] = $true
            $result += $pt
        }
    }

    return $result
}
function Import-KmlPlaces {
    param (
        [string]$KmlPath
    )

    [xml]$kml = Get-Content $KmlPath
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($kml.NameTable)
    $nsMgr.AddNamespace("kml", "http://www.opengis.net/kml/2.2")

    $placemarks = $kml.SelectNodes("//kml:Placemark", $nsMgr)
    $places = @()
    foreach ($pm in $placemarks) {
        $name = $pm.name
        $coordText = $pm.Point.coordinates
        if ($coordText) {
            $parts = $coordText -split ","
            $lon = [double]$parts[0]
            $lat = [double]$parts[1]
            $places += @{ Name = $name; Lat = $lat; Lon = $lon }
        }
    }
    $places = Remove-DuplicatePlaces -Places $places
    return $places
}
function Import-GpxPlaces {
    param (
        [string]$GpxPath
    )
    [xml]$gpx = Get-Content $GpxPath

    $wpts = $gpx.gpx.trk.trkseg.trkpt
    $places = @()
    foreach ($wpt in $wpts) {
        $name = $wpt.name
        $lat = [double]$wpt.lat
        $lon = [double]$wpt.lon
        $places += @{ Name = $name; Lat = $lat; Lon = $lon }
    }
    $places = Remove-DuplicatePlaces -Places $places
    return $places
}
function Export-GpxRoute {
    param (
        [array]$Route,
        [string]$OutputPath
    )
    $Route += $Route[0]
    $gpxXml = New-Object System.Xml.XmlDocument
    $gpxXml.AppendChild($gpxXml.CreateXmlDeclaration("1.0", "UTF-8", $null)) | Out-Null

    $gpxElem = $gpxXml.CreateElement("gpx")
    $gpxElem.SetAttribute("version", "1.1")
    $gpxElem.SetAttribute("creator", "RouteOptimizer")
    $gpxElem.SetAttribute("xmlns", "http://www.topografix.com/GPX/1/1")
    $gpxXml.AppendChild($gpxElem) | Out-Null

    $trkElem = $gpxXml.CreateElement("trk")
    $trksegElem = $gpxXml.CreateElement("trkseg")

    foreach ($pt in $Route) {
        $trkpt = $gpxXml.CreateElement("trkpt")
        $trkpt.SetAttribute("lat", "$($pt.Lat)")
        $trkpt.SetAttribute("lon", "$($pt.Lon)")

        if ($pt.Name) {
            $nameElem = $gpxXml.CreateElement("name")
            $nameElem.InnerText = $pt.Name
            $trkpt.AppendChild($nameElem) | Out-Null
        }

        $trksegElem.AppendChild($trkpt) | Out-Null
    }

    $trkElem.AppendChild($trksegElem) | Out-Null
    $gpxElem.AppendChild($trkElem) | Out-Null

    $gpxXml.Save($OutputPath)
    Write-Host "✅ GPXルートを保存しました: $OutputPath"
}
Export-ModuleMember -Function Import-KmlPlaces, Import-GpxPlaces, Export-GpxRoute, Remove-DuplicatePlaces

