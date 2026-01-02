class GeoService {
    # =========================================================
    # municipalities.json のパス（あとで変更可能）
    # =========================================================
    static [string] $MunicipalitiesPath = "D:\tool\Repository\PSTools\開発中\GPX4\municipalities.json"
    static [hashtable] $MunicipalitiesCache

    # スタティックコンストラクタ：クラス初期化時に一度だけ実行
    static GeoService() {
        $path = [GeoService]::MunicipalitiesPath

        if (-not (Test-Path $path)) {
            Write-Host "municipalities.json が見つかりません。生成を試みます..." -ForegroundColor Yellow
            [GeoService]::UpdateMunicipalitiesJson()
        }

        if (-not (Test-Path $path)) {
            throw "municipalities.json のロードに失敗しました: $path"
        }
        [GeoService]::MunicipalitiesCache = Get-Content -Raw -Path $path | ConvertFrom-Json -AsHashtable
    }

    # =========================================================
    # municipalities.json を DFP から生成（最終修正版）
    # =========================================================
    static [void] UpdateMunicipalitiesJson() {

        $output = [GeoService]::MunicipalitiesPath

        $endpoint = 'https://www.mlit-data.jp/api/v1/'
        $headers = @{
            "Content-Type" = "application/json"
            "apikey"       = "4ZiwH4ty7rcYPfye2sYP9DjX9BBjCOzY"
        }

        # -------------------------------
        # 1. 都道府県一覧
        # -------------------------------
        $prefQuery = @{
            query = @"
{
  prefecture {
    code
    name
  }
}
"@
        } | ConvertTo-Json -Depth 5

        $prefResponse = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $prefQuery
        $prefMap = @{}
        foreach ($p in $prefResponse.data.prefecture) {
            $prefCode = "{0:D2}" -f $p.code
            $prefMap[$prefCode] = $p.name
        }

        # -------------------------------
        # 2. 自治体一覧
        # -------------------------------
        $muniQuery = @{
            query = @"
{
  municipalities {
    code
    name
    prefecture_code
  }
}
"@
        } | ConvertTo-Json -Depth 5

        $muniResponse = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $muniQuery
        $municipalities = $muniResponse.data.municipalities

        # -------------------------------
        # 3. muniCd6 → muniCd5
        # -------------------------------
        $final = @()
        foreach ($m in $municipalities) {

            $muniCd6 = "{0:D6}" -f $m.code
            $muniCd5 = $muniCd6.Substring(0, 5)
            $prefCode = "{0:D2}" -f $m.prefecture_code

            $final += @{
                muniCd5         = $muniCd5
                muniCd6         = $muniCd6
                municipality    = $m.name
                prefecture      = $prefMap[$prefCode]
                prefecture_code = $prefCode
            }
        }

        # -------------------------------
        # 4. JSON 保存（固定パス）
        # -------------------------------
        @{ municipalities = $final } |
        ConvertTo-Json -Depth 10 |
        Out-File $output -Encoding utf8
    }

    # =========================================================
    # 1. SearchPlace（Nominatim）
    # キーワード → 複数候補
    # =========================================================
    static [hashtable[]] SearchPlace([string]$Keyword) {
        $url = "https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&q=$([uri]::EscapeDataString($Keyword))"
        $json = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "User-Agent" = "GeoService" }

        $results = @()
        foreach ($item in $json) {
            $extensions = @{}
            $item.address.psobject.properties | %{$extensions[$_.Name]=$_.Value}
            $place = @{extensions = $extensions }
            @('lat', 'lon', 'name', 'display_name') | ForEach-Object { $place[$_] = $item.$_ }
            $place = [GeoService]::ResolveAddress($place)
            $results += $place
        }
        return $results
    }

    # =========================================================
    # 2. ResolveAddress（GSI Reverse + municipalities.json）
    # 座標 → muniInfo（最終形）
    # =========================================================
    static [hashtable] ResolveAddress($Point) {
        # 入力が PSCustomObject の場合はハッシュテーブルに変換
        if ($Point -is [PSCustomObject]) {
            $Point = $Point | ConvertTo-Hashtable  # PowerShell 7+ の拡張機能、または自前実装
        }

        $lat = $Point['lat']
        $lon = $Point['lon']

        # GSI Reverse Geocoder
        $url = "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$lat&lon=$lon"
        $json = Invoke-RestMethod -Uri $url -Method Get

        $muniCd5 = $json.results.muniCd
        $town = $json.results.lv01Nm

        # municipalities.json から情報取得
        $muniInfo = [GeoService]::MunicipalitiesCache['municipalities'] | Where-Object { $_['muniCd5'] -eq $muniCd5 }

        if (-not $muniInfo) {
            return $Point
        }
        if (-not $Point.ContainsKey('name')) {
            $Point['name'] = $town
        }

        $extensions = if ($Point.ContainsKey('extensions')) { $Point['extensions'] } else { @{} }
        foreach ($prop in $muniInfo.GetEnumerator()) {
            $extensions[$prop.Key] = $prop.Value
        }
        $extensions['block'] = $town
        $Point['extensions'] = $extensions

        return $Point
    }

    # =========================================================
    # 3. QueryTowns（Geolonia）
    # muniCd5 ではなく prefecture / municipality 名で取得
    # =========================================================
    static [hashtable[]] QueryTowns([hashtable]$Trkpt) {
        $pref = $Trkpt['extensions']['prefecture']
        $muni = $Trkpt['extensions']['municipality']

        $url = "https://geolonia.github.io/japanese-addresses/api/ja/$pref/$muni.json"
        try {
            $json = Invoke-RestMethod -Uri $url -Method Get
        }
        catch {
            return @()
        }
        $results = @()
        foreach ($town in $json) {
            $ext = @{
                prefecture   = $pref
                municipality = $muni
                muniCd5      = $Trkpt['extensions']['muniCd5']
                block        = $town.town
            }
            $results += @{
                lat        = [double]$town.lat
                lon        = [double]$town.lng
                name       = $town.town
                extensions = $ext
            }
        }
        return $results
    }

    # =========================================================
    # 4. QueryArea（Overpass）
    # 中心座標 + 半径 → 町字一覧
    # =========================================================
    static [hashtable[]] QueryArea([hashtable]$Center, [double]$RadiusMeters) {
        $lat = $Center['lat']
        $lon = $Center['lon']

        $query = @"
[out:json];
node(around:$RadiusMeters,$lat,$lon)["place"~"^(neighbourhood|quarter)$"];
out body;
"@

        $url = "https://overpass-api.de/api/interpreter"
        $maxRetries = 3
        $retryDelaySec = 2
        $json = $null
        $success = $false

        $swOverpass = [System.Diagnostics.Stopwatch]::StartNew()

        for ($i = 0; $i -lt $maxRetries; $i++) {
            try {
                $json = Invoke-RestMethod -Uri $url -Method Post -Body $query -ContentType "text/plain"
                $success = $true
                break
            }
            catch {
                Write-Warning "Overpass API リクエスト失敗（$($i+1)/$maxRetries）: $_"
                Start-Sleep -Seconds $retryDelaySec
            }
        }

        $swOverpass.Stop()

        if (-not $success) {
            throw "Overpass API リクエストに $maxRetries 回失敗しました。"
        }

        $results = @()
        $resolveLog = @()
        $swResolveTotal = [System.Diagnostics.Stopwatch]::StartNew()

        foreach ($node in $json.elements) {
            $swEach = [System.Diagnostics.Stopwatch]::StartNew()

            $place = @{
                lat  = [double]$node.lat
                lon  = [double]$node.lon
                name = $node.tags.name
            }
            $results += $place

            $swEach.Stop()
            $resolveLog += @{
                Name   = $place['name']
                TimeMs = [math]::Round($swEach.Elapsed.TotalMilliseconds, 2)
            }
        }

        $swResolveTotal.Stop()

        # ログ出力
        Write-Host ""
        Write-Host ("[Overpass] リクエスト処理時間: {0:N2} ms" -f $swOverpass.Elapsed.TotalMilliseconds)
        Write-Host ("[ResolveAddress] 合計処理時間: {0:N2} ms" -f $swResolveTotal.Elapsed.TotalMilliseconds)
        Write-Host "[ResolveAddress] 各地点の処理時間:"
        $resolveLog | Format-Table -AutoSize

        return $results
    }
}


$y = [GeoService]::SearchPlace("横須賀市")

$towns = [GeoService]::QueryTowns($y[0])
$area = [GeoService]::QueryArea($y[0],1000)

