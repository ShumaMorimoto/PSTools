# KMLファイルのパス
$kmlPath = "C:\Users\shuma\Downloads\仙台茶屋.kml"
[xml]$kml = Get-Content $kmlPath
$nsMgr = New-Object System.Xml.XmlNamespaceManager($kml.NameTable)
$nsMgr.AddNamespace("kml", "http://www.opengis.net/kml/2.2")

# 拠点抽出
$placemarks = $kml.SelectNodes("//kml:Placemark", $nsMgr)
$places = @()
foreach ($pm in $placemarks) {
    $name = $pm.name
    $coordText = $pm.Point.coordinates
    if ($coordText) {
        $parts = $coordText -split ","
        $lon = [double]$parts[0]
        $lat = [double]$parts[1]
        $places += @{
            Name = $name
            Lat = $lat
            Lon = $lon
        }
    }
}

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
        $sum += Get-Distance $route[$i] $route[$i+1]
    }
    return $sum
}

function Get-RandomRoute($places) {
    return $places | Sort-Object {Get-Random}
}

function Mutate($route) {
    # ディープコピー（新しい place オブジェクトを作る）
    $newRoute = @()
    foreach ($pt in $route) {
        $newRoute += ,@{ Name = $pt.Name; Lat = $pt.Lat; Lon = $pt.Lon }
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

# 初期集団
$populationSize = 50
$generations = 100
$population = @()
for ($i = 0; $i -lt $populationSize; $i++) {
    $population += ,(Get-RandomRoute $places)
}

# GAループ
for ($gen = 0; $gen -lt $generations; $gen++) {
    $population = $population | Sort-Object { Get-TotalDistance $_ }
    $best = $population[0]

    # 異常チェック
    if (-not $best -or $best.Count -lt 2) {
        Write-Host "⚠️ 世代 $gen で異常な個体が検出されました。"
        break
    }

    $distance = Get-TotalDistance $best
    Write-Host "世代 $gen - 最短距離: $([math]::Round($distance, 2)) km"
    Write-Host "ルート: " + ($best | ForEach-Object { $_.Name }) -join " → "
    Write-Host ""

    # 新しい集団の生成
    $newPopulation = @()
    $newPopulation += ,$best  # エリート保存

    while ($newPopulation.Count -lt $populationSize) {
        $parent = $population[(Get-Random -Minimum 0 -Maximum 10)]
        $child = Mutate $parent
        if ($child.Count -eq $places.Count) {
            $newPopulation += ,$child
        }
    }

    $population = $newPopulation
}