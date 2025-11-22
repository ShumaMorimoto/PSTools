function Get-TownsAround {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Keyword,              # 検索キーワード（駅・城・ランドマークなど）
        [double]$RadiusKm = 2.0,             # 半径 (km)
        [string]$UserAgent = "PowerShell-Nominatim-Client",
        [switch]$SkipReverse
    )

    $nominatimUrl = "https://nominatim.openstreetmap.org/search"
    $overpassUrl  = "https://overpass-api.de/api/interpreter"
    $reverseUrl   = "https://nominatim.openstreetmap.org/reverse"

    $headers = @{ "User-Agent" = $UserAgent }

    # Step 1: キーワードから候補検索（自治体に限定せず）
    $nominatimParams = @{
        q              = $Keyword
        countrycodes   = 'jp'
        format         = 'json'
        addressdetails = 1
        limit          = 20
    }
    try {
        $results = Invoke-RestMethod -Uri $nominatimUrl -Method Get -Body $nominatimParams -Headers $headers
    }
    catch {
        Write-Error "Nominatim検索失敗: $_"
        return
    }

    if (-not $results) {
        Write-Warning "候補が見つかりませんでした。"
        return
    }

    # 複数候補なら選択
    $target = if ($results.Count -eq 1) {
        $results[0]
    }
    else {
        Write-Host "候補一覧："
        for ($i=0; $i -lt $results.Count; $i++) {
            Write-Host (" {0,2}: {1}" -f ($i+1), $results[$i].display_name)
        }
        do {
            $sel = Read-Host "番号を選択 (1-$($results.Count)) または qで中止"
            if ($sel -eq 'q') { return }
        } while (-not ($sel -match '^\d+$' -and $sel -ge 1 -and $sel -le $results.Count))
        $results[[int]$sel - 1]
    }

    $lat = $target.lat
    $lon = $target.lon
    Write-Host "拠点: $($target.display_name) ($lat,$lon)" -ForegroundColor Yellow

    # Step 2: 半径以内の町字ノードを取得
    $radiusM = [math]::Round($RadiusKm * 1000)
    $query = @"
[out:json];
node(around:$radiusM,$lat,$lon)["place"];
out body;
"@

    try {
        $townResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $query -Headers $headers
    }
    catch {
        Write-Error "町字一覧取得失敗: $_"
        return
    }

    # 集計
    $placeStats = $townResult.elements | Where-Object { $_.tags.place } | Group-Object { $_.tags.place }
    Write-Host "=== tags.place 集計 ==="
    foreach ($stat in $placeStats) {
        Write-Host ("{0}: {1}件" -f $stat.Name, $stat.Count)
    }
    Write-Host "========================"

    # 町字フィルタ
    $towns = $townResult.elements | Where-Object {
        $_.tags.name -and ($_.tags.place -in @('neighbourhood','quarter','hamlet'))
    }
    if (-not $towns) {
        Write-Warning "町字が見つかりませんでした。"
        return
    }

    # Step 3: GPX構築
    $doc = [GPXDocument]::new("RouteOptimizer", $target.display_name)

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
    $doc.SetTrkName($target.display_name + " 半径${RadiusKm}km以内")
    $doc.UpdateStats()

    return [GPXDocument]$doc
}