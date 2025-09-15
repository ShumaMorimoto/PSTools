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
function IsSamePoint($a, $b) {
    return ($a.Lat -eq $b.Lat -and $a.Lon -eq $b.Lon)
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
function Select-Parent($population, $tournamentSize = 5) {
    $candidates = @()
    for ($i = 0; $i -lt $tournamentSize; $i++) {
        $candidates += ,$population[(Get-Random -Minimum 0 -Maximum $population.Count)]
    }
    return ($candidates | Sort-Object { Get-TotalDistance $_ })[0]
}
function Crossover($parent1, $parent2) {
    $size = $parent1.Count
    $child = @(for ($i = 0; $i -lt $size; $i++) { $null })

    $start = Get-Random -Minimum 0 -Maximum $size
    $end = Get-Random -Minimum $start -Maximum $size

    # 親1の区間をコピー
    for ($i = $start; $i -lt $end; $i++) {
        $child[$i] = $parent1[$i]
    }

    # 親2の順序で残りを埋める
    foreach ($pt in $parent2) {
        if (-not ($child | Where-Object { IsSamePoint $_ $pt })) {
            for ($i = 0; $i -lt $size; $i++) {
                if (-not $child[$i]) {
                    $child[$i] = $pt
                    break
                }
            }
        }
    }
    return $child
}
function Get-Fitness($route) {
    $distance = Get-TotalDistance $route

    # 前半に訪問する地点の数（＝ルートの半分）
    $half = [math]::Floor($route.Count / 2)

    # 前半にいる地点の「順序スコア」を加算（早いほど良い）
    $orderScore = 0
    for ($i = 0; $i -lt $route.Count; $i++) {
        $weight = ($route.Count - $i)  # 早いほど重みが大きい
        $orderScore += $weight
    }

    # 総合スコア：距離 - 順序スコア × 重み
    return $distance - ($orderScore * 0.01)  # 重みは調整可能
}
Export-ModuleMember -Function Get-Distance, Get-TotalDistance, Get-RandomRoute, Mutate, Select-Parent, Crosover, Get-Fitness
function Optimize-Route {
    param (
        [array]$Places,
        [int]$PopulationSize = 50,
        [int]$Generations = 100,
        [ScriptBlock]$OnGeneration = $null  # ← コールバック
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

        # コールバック呼び出し
        if ($OnGeneration) {
            & $OnGeneration $gen $best $distance
        }
        else {
            Write-Host "世代 $gen - 最短距離: $([math]::Round($distance, 2)) km"
            #        Write-Host "ルート: " + ($best | ForEach-Object { $_.Name }) -join " → "
            #        Write-Host ""
        }

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
function Optimize-Route2 {
    param (
        [array]$Places,
        [int]$PopulationSize = 50,
        [int]$Generations = 100,
        [ScriptBlock]$OnGeneration = $null,
        [ScriptBlock]$FitnessFunction = $null  # ← 評価関数を追加
    )

    # デフォルト評価関数（総距離）
    if (-not $FitnessFunction) {
        $FitnessFunction = { param($route) Get-TotalDistance $route }
    }

    $population = @()
    for ($i = 0; $i -lt $PopulationSize; $i++) {
        $population += , (Get-RandomRoute $Places)
    }

    for ($gen = 0; $gen -lt $Generations; $gen++) {
        $population = $population | Sort-Object { & $FitnessFunction $_ }
        $best = $population[0]
        $distance = Get-TotalDistance $best

        if ($OnGeneration) {
            & $OnGeneration $gen $best $distance
        }
        else {
            Write-Host "世代 $gen - 最短距離: $([math]::Round($distance, 2)) km"
        }

        $newPopulation = @()
        $newPopulation += , $best  # エリート保存

        while ($newPopulation.Count -lt $PopulationSize) {
            $parent1 = Select-Parent $population
            $parent2 = Select-Parent $population

            $child = Crossover $parent1 $parent2
            $child = Mutate $child

            if ($child.Count -eq $Places.Count) {
                $newPopulation += , $child
            }
        }
        $population = $newPopulation
    }
    return $best
}
Export-ModuleMember -Function Optimize-Route, Optimize-Route2
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

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Start-RouteAnimation {
    param (
        [array]$Places,
        [int]$Generations = 50
    )
    # フォーム作成
    $form = New-Object Windows.Forms.Form
    $form.Text = "GAルート最適化アニメーション"
    $form.Width = 800
    $form.Height = 600

    $pictureBox = New-Object Windows.Forms.PictureBox
    $pictureBox.Dock = "Fill"
    $form.Controls.Add($pictureBox)
    $form.Show()

    # 緯度経度の範囲を取得
    $minLat = ($Places | Measure-Object -Property Lat -Minimum).Minimum
    $maxLat = ($Places | Measure-Object -Property Lat -Maximum).Maximum
    $minLon = ($Places | Measure-Object -Property Lon -Minimum).Minimum
    $maxLon = ($Places | Measure-Object -Property Lon -Maximum).Maximum

    # 緯度経度 → XY座標変換関数
    function Convert-ToXY($lat, $lon) {
        $x = ($lon - $minLon) / ($maxLon - $minLon) * ($form.Width - 40) + 20
        $y = ($maxLat - $lat) / ($maxLat - $minLat) * ($form.Height - 40) + 20
        return @{ X = [int]$x; Y = [int]$y }
    }

    # 描画関数（世代ごとに呼び出される）
    function Draw-Route {
        param ($gen, $route, $distance)

        $bitmap = New-Object Drawing.Bitmap $form.Width, $form.Height
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([Drawing.Color]::White)

        # 線描画
        for ($i = 0; $i -lt $route.Count; $i++) {
            $pt1 = Convert-ToXY $route[$i].Lat $route[$i].Lon
            $pt2 = Convert-ToXY $route[($i + 1) % $route.Count].Lat $route[($i + 1) % $route.Count].Lon
            $graphics.DrawLine([Drawing.Pens]::Blue, $pt1.X, $pt1.Y, $pt2.X, $pt2.Y)
        }

        # 地点描画
        foreach ($pt in $route) {
            $xy = Convert-ToXY $pt.Lat $pt.Lon
            $graphics.FillEllipse([Drawing.Brushes]::Red, $xy.X - 4, $xy.Y - 4, 8, 8)
            $graphics.DrawString($pt.Name, [Drawing.Font]::new("Arial", 8), [Drawing.Brushes]::Black, $xy.X + 5, $xy.Y - 10)
        }

        # 世代と距離の表示
        $graphics.DrawString("世代 $gen - 距離: $([math]::Round($distance, 2)) km", [Drawing.Font]::new("Arial", 12), [Drawing.Brushes]::Black, 20, 20)

        $pictureBox.Image = $bitmap
        $form.Refresh()
        Start-Sleep -Milliseconds 300
    }

    # GAを実行し、描画関数をコールバックとして渡す
    Optimize-Route -Places $Places -Generations $Generations -OnGeneration { param($g, $r, $d) Draw-Route $g $r $d }
}
Export-ModuleMember -Function Start-RouteAnimation
