function Get-CityTowns {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Keyword,
        [string]$UserAgent = "PowerShell-Nominatim-Client",
        [switch]$SkipReverse
    )

    $nominatimUrl = "https://nominatim.openstreetmap.org/search"
    $overpassUrl = "https://overpass-api.de/api/interpreter"
    $reverseUrl = "https://nominatim.openstreetmap.org/reverse"

    # Step 1: 自治体候補検索
    $nominatimParams = @{
        q              = $Keyword
        countrycodes   = 'jp'
        format         = 'json'
        addressdetails = 1
        featuretype    = 'city'
        limit          = 100
    }

    $headers = @{ "User-Agent" = $UserAgent }

    try {
        $results = Invoke-RestMethod -Uri $nominatimUrl -Method Get -Body $nominatimParams -Headers $headers
    }
    catch {
        Write-Error "Nominatim検索失敗: $_"
        return
    }

    $results = $results | Where-Object { $_.addresstype -in @("city", "town", "village", "suburb") }

    if (-not $results) {
        Write-Warning "候補が見つかりませんでした。"
        return
    }

    $target = if ($results.Count -eq 1) {
        $results[0]
    }
    else {
        Write-Host "候補一覧："
        for ($i = 0; $i -lt $results.Count; $i++) {
            Write-Host (" {0,2}: {1}" -f ($i + 1), $results[$i].display_name)
        }
        do {
            $sel = Read-Host "番号を選択 (1-$($results.Count)) または qで中止"
            if ($sel -eq 'q') { return }
        } while (-not ($sel -match '^\d+$' -and $sel -ge 1 -and $sel -le $results.Count))
        $results[[int]$sel - 1]
    }

    $lat = $target.lat
    $lon = $target.lon

    # Step 2: relation ID取得
    $queryRel = @"
[out:json];
is_in($lat,$lon)->.a;
rel(pivot.a)["boundary"="administrative"]["admin_level"~"^[6-8]$"];
out body;
"@

    try {
        $relResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $queryRel -Headers $headers
    }
    catch {
        Write-Error "Overpass relation取得失敗: $_"
        return
    }

    $relation = $relResult.elements | Sort-Object { [int]$_.tags.admin_level } -Descending | Select-Object -First 1
    if (-not $relation.id) {
        Write-Warning "relation IDが取得できませんでした。"
        return
    }

    $areaId = 3600000000 + $relation.id

    # Step 3: 町字一覧取得
    $queryTowns = @"
[out:json];
area($areaId)->.searchArea;
node(area.searchArea)["place"];
out body;
"@

    try {
        $townResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $queryTowns -Headers $headers
    }
    catch {
        Write-Error "町字一覧取得失敗: $_"
        return
    }

    # --- 集計追加 ---
    $placeStats = $townResult.elements | Where-Object { $_.tags.place } | Group-Object { $_.tags.place }
    Write-Host "=== tags.place 集計 ==="
    foreach ($stat in $placeStats) {
        Write-Host ("{0}: {1}件" -f $stat.Name, $stat.Count)
    }
    Write-Host "========================"

    # 町字フィルタ（neighbourhood, quarter, hamlet を対象）
    $towns = $townResult.elements | Where-Object {
        $_.tags.name -and ($_.tags.place -in @('neighbourhood', 'quarter'))
    }
    if (-not $towns) {
        Write-Warning "町字が見つかりませんでした。"
        return
    }

    # Step 4: GPX構築
    $doc = [GPXDocument]::new("RouteOptimizer", $target.name)

    $total = $towns.Count
    $index = 0
    foreach ($town in $towns) {
        $index++
        $tLat = $town.lat
        $tLon = $town.lon
        $name = $town.tags.name

        Write-Host "📍 [$index/$total] $name ($tLat, $tLon)" -ForegroundColor Cyan

        if (-not $SkipReverse) {
            $uri = "${reverseUrl}?lat=$tLat&lon=$tLon&format=json&addressdetails=1"
            try {
                $res = Invoke-RestMethod -Uri $uri -Headers $headers
                $addr = $res.address
                $desc = $res.display_name
            }
            catch {
                Write-Warning "[$tLat,$tLon] 逆ジオコーディング失敗: $_"
                $addr = $null
                $desc = $null
            }
        }
        else {
            $addr = $null
            $desc = $name
        }

        $doc.AddTrkPt([double]$tLat, [double]$tLon, $name, $desc, $addr)
    }
    $doc.SetTrkName($target.name + "の周遊")
    $doc.UpdateStats()

    return [GPXDocument]$doc
}