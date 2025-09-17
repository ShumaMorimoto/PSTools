function Get-CityCandidates {
    param (
        [string]$keyword
    )

    $query = @"
[out:json];
node["name"="$keyword"];
out body;
"@

    $url = "https://overpass-api.de/api/interpreter"
    $headers = @{ "User-Agent" = "PowerShellScript/1.0 (your_email@example.com)" }
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $query -ContentType "application/x-www-form-urlencoded"

    $results = @()
    foreach ($node in $response.elements) {
        $lat = $node.lat
        $lon = $node.lon
        $nominatimUrl = "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json"
        $nominatim = Invoke-RestMethod -Uri $nominatimUrl -Headers $headers
        $addr = $nominatim.address

        $parts = @()
        if ($addr.province) { $parts += $addr.province }
        if ($addr.county)   { $parts += $addr.county }
        if ($addr.town)     { $parts += $addr.town }
        if ($addr.village)  { $parts += $addr.village }
        if ($addr.city)     { $parts += $addr.city }
        elseif ($addr.suburb) { $parts += $addr.suburb }

        $label = $parts -join " "

        $results += [PSCustomObject]@{
            ID = $node.id
            Lat = $lat
            Lon = $lon
            Label = $label
        }
    }

    return $results
}

function Get-RelationFromLocation {
    param (
        [double]$lat,
        [double]$lon
    )

    $query = @"
[out:json];
is_in($lat,$lon)->.a;
rel(pivot.a)["boundary"="administrative"]["admin_level"~"^[6-8]$"];
out body;
"@

    $url = "https://overpass-api.de/api/interpreter"
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $query -ContentType "application/x-www-form-urlencoded"

    $relation = $response.elements | Sort-Object {[int]$_.tags.admin_level} -Descending | Select-Object -First 1
    return $relation.id
}

function Get-TownNamesFromRelation {
    param (
        [long]$relationId
    )

    $areaId = 3600000000 + $relationId
    $query = @"
[out:json];
area($areaId)->.searchArea;
node(area.searchArea)["place"];
out body;
"@

    $url = "https://overpass-api.de/api/interpreter"
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $query -ContentType "application/x-www-form-urlencoded"

    $towns = $response.elements | Where-Object { $_.tags.name } | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.tags.name
            Lat  = $_.lat
            Lon  = $_.lon
        }
    }

    return $towns | Sort-Object Name
}

function Convert-TownsToGPX {
    param (
        [array]$towns,
        [string]$routeName = "町字一覧"
    )

    $gpxHeader = @'
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="TownGPXConverter" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>{ROUTE_NAME}</name>
    <trkseg>
'@ -replace '{ROUTE_NAME}', $routeName

    $gpxPoints = $towns | ForEach-Object {
        "      <trkpt lat=""$($_.Lat)"" lon=""$($_.Lon)""><name>$($_.Name)</name></trkpt>"
    }

    $gpxFooter = @'
    </trkseg>
  </trk>
</gpx>
'@

    return $gpxHeader + ($gpxPoints -join "`n") + "`n" + $gpxFooter
}

function Search-CityTowns {
    param (
        [string]$keyword
    )

    $candidates = Get-CityCandidates -keyword $keyword
    if ($candidates.Count -eq 0) {
        Write-Host "候補が見つかりませんでした。"
        return
    }

    if ($candidates.Count -eq 1) {
        $selected = $candidates[0]
        Write-Host "`n候補が1件のみ見つかりました：$($selected.Label)"
    } else {
        Write-Host "`n候補一覧："
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "$($i): $($candidates[$i].Label)"
        }

        $inputRaw = Read-Host "番号を選択してください"
        if (-not ($inputRaw -match '^\d+$')) {
            Write-Host "無効な入力です。"
            return
        }
        $index = [int]$inputRaw
        if ($index -ge $candidates.Count) {
            Write-Host "番号が範囲外です。"
            return
        }

        $selected = $candidates[$index]
    }

    $relationId = Get-RelationFromLocation -lat $selected.Lat -lon $selected.Lon
    if (-not $relationId) {
        Write-Host "対応する行政区画が見つかりませんでした。"
        return
    }

    $towns = Get-TownNamesFromRelation -relationId $relationId
    Write-Host "`n町字一覧："
    foreach ($town in $towns) {
        Write-Host "- $($town.Name) ($($town.Lat), $($town.Lon))"
    }
    Write-Host "`n合計: $($towns.Count)件"

    $gpxContent = Convert-TownsToGPX -towns $towns -routeName $selected.Label
    $fileName = "$($selected.Label)_towns.gpx" -replace '\s', '_'
    Set-Content -Path $fileName -Value $gpxContent -Encoding UTF8
    Write-Host "`nGPXファイルを保存しました：$fileName"
}

# 実行例
# Search-CityTowns -keyword "中央区"