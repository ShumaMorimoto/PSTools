function Get-CityTowns {
    <#
    .SYNOPSIS
        指定された地名キーワードに基づいて、その地域の町字一覧を取得します。
    .DESCRIPTION
        Nominatim APIで地名の候補を検索し、ユーザーが選択した地域の町字（neighbourhood）一覧と座標を出力します。
    .PARAMETER Keyword
        検索したい地名キーワードを指定します。（例: "横浜", "渋谷"）
    .EXAMPLE
        Get-TownListFromKeyword -Keyword "横浜"
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$Keyword
    )

    $nominatimUrl = "https://nominatim.openstreetmap.org/search"
    $overpassUrl = "https://overpass-api.de/api/interpreter"

    Write-Host "🔍 地名検索中: $Keyword"

    $nominatimParams = @{
        q              = $Keyword
        countrycodes   = 'jp'
        format         = 'json'
        addressdetails = 1
        featuretype    = 'city'
        limit          = 100
    }

    try {
        $nominatimResult = Invoke-RestMethod -Uri $nominatimUrl -Method Get -Body $nominatimParams -ErrorAction Stop
    } catch {
        Write-Error "❌ Nominatim APIへのアクセス中にエラーが発生しました: $($_.Exception.Message)"
        return
    }

    $nominatimResult = $nominatimResult | Where-Object { $_.addresstype -in @("city", "town", "village", "suburb") }

    if (-not $nominatimResult) {
        Write-Error "⚠️ 地名が見つかりませんでした: '$Keyword'"
        return
    }

    $targetLocation = $null

    if (@($nominatimResult).Count -eq 1) {
        $targetLocation = $nominatimResult[0]
        Write-Host "✅ 候補が1件見つかりました: $($targetLocation.display_name)"
    } else {
        Write-Host "🗂️ 複数の候補が見つかりました。番号を選択してください："
        for ($i = 0; $i -lt $nominatimResult.Count; $i++) {
            Write-Host (" {0,2}: {1}" -f ($i + 1), $nominatimResult[$i].display_name)
        }

        while ($true) {
            $input = Read-Host "🔢 番号を入力 (1-$($nominatimResult.Count))、または 'q' で終了"
            if ($input -eq 'q') {
                Write-Host "🚪 処理を中断しました。"
                return
            }
            if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le $nominatimResult.Count) {
                $targetLocation = $nominatimResult[[int]$input - 1]
                break
            } else {
                Write-Warning "⚠️ 無効な入力です。1〜$($nominatimResult.Count) の番号を入力してください。"
            }
        }
    }

    $lat = $targetLocation.lat
    $lon = $targetLocation.lon
    $displayName = $targetLocation.display_name

    Write-Host "`n📍 選択された候補: $displayName"
    Write-Host "🌍 座標: $lat, $lon"

    Write-Host "`n📡 Overpassで自治体relation ID取得中..."

    $overpassQuery = @"
[out:json];
is_in($lat,$lon)->.a;
rel(pivot.a)["boundary"="administrative"]["admin_level"~"^[6-8]$"];
out body;
"@

    $relationResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $overpassQuery
    $relation = $relationResult.elements | Sort-Object { [int]$_.tags.admin_level } -Descending | Select-Object -First 1
    $relationId = $relation.id

    if (-not $relationId) {
        Write-Error "❌ relation IDが取得できませんでした。"
        return
    }

    $areaId = 3600000000 + $relationId
    Write-Host "🆔 relation ID: $relationId"
    Write-Host "🌐 area ID: $areaId"

    Write-Host "`n📋 町字一覧取得中..."

    $townQuery = @"
[out:json];
area($areaId)->.searchArea;
node(area.searchArea)["place"];
out body;
"@

    $townResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $townQuery
    $towns = $townResult.elements | Where-Object { $_.tags.name } | Sort-Object { $_.tags.name }
    $towns = $towns | Where-Object { $_.tags.place -notin @("city", "town", "village", "suburb") }

    if ($towns) {
        foreach ($town in $towns) {
            $lat = $town.lat ? $town.lat : $town.center.lat
            $lon = $town.lon ? $town.lon : $town.center.lon
            Write-Host "📍 $($town.tags.name)  ($lat, $lon)"
        }
        Write-Host "`n✅ 取得した町字数: $($towns.Count)" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ このエリアには 'neighbourhood' として登録されている町字が見つかりませんでした。"
    }

    return $towns
}