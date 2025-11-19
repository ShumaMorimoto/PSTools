function Get-CityTowns {
    [CmdletBinding()]    
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
#    $overpassUrl = "https://overpass.private.coffee/api/interpreter"
#    $overpassUrl = "https://overpass.openstreetmap.fr/api/interpreter"

    Write-Verbose "🔍 地名検索中: $Keyword"

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
    }
    catch {
        Write-Error "❌ Nominatim APIへのアクセス失敗: $($_.Exception.Message)"
        return
    }

    $nominatimResult = $nominatimResult | Where-Object { $_.addresstype -in @("city", "town", "village", "suburb") }

    if (-not $nominatimResult) {
        Write-Warning "⚠️ 地名が見つかりませんでした: '$Keyword'"
        return
    }

    $targetLocation = $null

    if ($nominatimResult.Count -eq 1) {
        $targetLocation = $nominatimResult[0]
        Write-Verbose "✅ 候補が1件見つかりました: $($targetLocation.display_name)"
    }
    else {
        Write-Host "🗂️ 複数候補あり。番号を選択してください："
        for ($i = 0; $i -lt $nominatimResult.Count; $i++) {
            Write-Host (" {0,2}: {1}" -f ($i + 1), $nominatimResult[$i].display_name)
        }

        while ($true) {
            $input = Read-Host "🔢 番号を入力 (1-$($nominatimResult.Count))、または 'q' で終了"
            if ($input -eq 'q') {
                Write-Warning "🚪 処理を中断しました。"
                return
            }
            if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le $nominatimResult.Count) {
                $targetLocation = $nominatimResult[[int]$input - 1]
                break
            }
            else {
                Write-Warning "⚠️ 無効な入力です。1〜$($nominatimResult.Count) の番号を入力してください。"
            }
        }
    }

    $lat = $targetLocation.lat
    $lon = $targetLocation.lon
    $displayName = $targetLocation.display_name

    Write-Verbose "`n📍 選択された候補: $displayName"
    Write-Verbose "🌍 座標: $lat, $lon"

    $overpassQuery = @"
[out:json];
is_in($lat,$lon)->.a;
rel(pivot.a)["boundary"="administrative"]["admin_level"~"^[6-8]$"];
out body;
"@

    try {
        $relationResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $overpassQuery -ErrorAction Stop
    }
    catch {
        Write-Error "❌ Overpass APIへのアクセス失敗: $($_.Exception.Message)"
        return
    }

    $relation = $relationResult.elements | Sort-Object { [int]$_.tags.admin_level } -Descending | Select-Object -First 1
    $relationId = $relation.id

    if (-not $relationId) {
        Write-Warning "❌ relation IDが取得できませんでした。"
        return
    }

    $areaId = 3600000000 + $relationId
    Write-Verbose "🆔 relation ID: $relationId"
    Write-Verbose "🌐 area ID: $areaId"

    $townQuery = @"
[out:json];
area($areaId)->.searchArea;
node(area.searchArea)["place"];
out body;
"@

    try {
        $townResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $townQuery -ErrorAction Stop
    }
    catch {
        Write-Error "❌ 町字一覧取得中にエラー: $($_.Exception.Message)"
        return
    }

    $towns = $townResult.elements | Where-Object { $_.tags.name } | Sort-Object { $_.tags.name }
    $towns = $towns | Where-Object { $_.tags.place -notin @("city", "town", "village", "suburb") }

    if ($towns) {
        foreach ($town in $towns) {
            $lat = $town.lat ? $town.lat : $town.center.lat
            $lon = $town.lon ? $town.lon : $town.center.lon
            Write-Host "📍 $($town.tags.name)  ($lat, $lon)"
        }
        Write-Host "`n✅ 取得した町字数: $($towns.Count)" -ForegroundColor Green
    }
    else {
        Write-Warning "ℹ️ このエリアには 'neighbourhood' として登録されている町字が見つかりませんでした。"
    }

    return $towns
}

function Get-Place {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [object]$InputObject
    )

    begin {
        $headers = @{ "User-Agent" = "PowerShell-ReverseGeocoding" }
        $doc = New-Object System.Xml.XmlDocument
    }

    process {
        # lat/lon抽出（trkptノード or 任意オブジェクト対応）
        $lat = $InputObject.lat ?? $InputObject.Latitude
        $lon = $InputObject.lon ?? $InputObject.Longitude

        if (-not ($lat -and $lon)) {
            Write-Warning "緯度経度が見つかりません: $($InputObject | Out-String)"
            return
        }

        $uri = "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1"

        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop
            $addr = $response.address
            $display = $response.display_name
            $townArea = $addr.road ?? $addr.suburb ?? $addr.neighbourhood ?? $addr.city ?? 'Unknown'

            # 入力がtrkptノードならコピーして使う
            if ($InputObject -is [System.Xml.XmlElement] -and $InputObject.Name -eq "trkpt") {
                $trkpt = $doc.ImportNode($InputObject, $true)

                # name, desc, extensions をすべて削除
                foreach ($tag in @("name", "desc", "extensions")) {
                    $nodes = $trkpt.SelectNodes($tag)
                    foreach ($node in $nodes) {
                        $trkpt.RemoveChild($node) | Out-Null
                    }
                }
            }
            else {
                # 新規trkptノードを作成
                $trkpt = $doc.CreateElement("trkpt")
                $trkpt.SetAttribute("lat", $lat.ToString())
                $trkpt.SetAttribute("lon", $lon.ToString())
            }

            # nameノード
            $nameNode = $doc.CreateElement("name")
            $nameNode.InnerText = $townArea
            $trkpt.AppendChild($nameNode) | Out-Null

            # descノード
            $descNode = $doc.CreateElement("desc")
            $descNode.InnerText = $display
            $trkpt.AppendChild($descNode) | Out-Null

            # extensionsノード
            $extNode = $doc.CreateElement("extensions")
            foreach ($key in $addr.PSObject.Properties.Name) {
                $val = $addr.$key
                if ($val) {
                    $child = $doc.CreateElement($key)
                    $child.InnerText = $val
                    $extNode.AppendChild($child) | Out-Null
                }
            }
            $trkpt.AppendChild($extNode) | Out-Null

            return $trkpt
        }
        catch {
            Write-Warning "[$lat,$lon] 逆ジオコーディング失敗: $($_.Exception.Message)"
        }
    }
}