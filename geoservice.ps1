class GeoService {
    # =========================================================
    # 設定・キャッシュ
    # =========================================================
    static [string] $MunicipalitiesPath = (Join-Path $script:ModuleRoot "data\municipalities.json")
    static [hashtable] $MunicipalitiesCache = $null
    static [hashtable] $NominatimCache = @{}
    
    # Nominatim用レート制限 (前回リクエスト時刻)
    static [DateTime] $LastNominatimRequest = [DateTime]::MinValue

    # スタティックコンストラクタ（モジュールロード時に実行）
    static GeoService() {
        if (Test-Path [GeoService]::MunicipalitiesPath) {
            try {
                $jsonContent = Get-Content -Raw -Path [GeoService]::MunicipalitiesPath -Encoding UTF8
                [GeoService]::MunicipalitiesCache = $jsonContent | ConvertFrom-Json -AsHashtable
            }
            catch {
                Write-Warning "Failed to load municipalities.json: $_"
            }
        }
    }

    # =========================================================
    # 内部用: Pointハッシュテーブルの生成
    # =========================================================
    static [hashtable] _CreatePoint($lat, $lon, $name, $desc, $extData) {
        $exts = if ($extData) { $extData } else { @{} }
        return @{
            lat        = [double]$lat
            lon        = [double]$lon
            name       = "$name"
            desc       = "$desc"
            extensions = @{
                muniCd5      = "$($exts.muniCd5)"
                municipality = "$($exts.municipality)"
                prefecture   = "$($exts.prefecture)"
                town         = if ($exts.town) { "$($exts.town)" } elseif ($exts.block) { "$($exts.block)" } else { "" }
            }
        }
    }

    # =========================================================
    # 1. Resolve: 座標 -> 施設名/詳細住所 (Nominatim優先 + GSI)
    # =========================================================
    static [hashtable] Resolve([hashtable]$Point) {
        # 1. まず住所ベース(GSI)を取得しておく (これがベースとなる)
        $basePoint = [GeoService]::ResolveAddress($Point)

        # 2. Nominatimで詳細な場所名を取りに行く
        try {
            $nominatimData = [GeoService]::_FetchNominatim($Point)

            # Nominatimから名前が取れた場合
            if ($nominatimData -and $nominatimData.name) {
                return [GeoService]::_CreatePoint(
                    $Point.lat,
                    $Point.lon,
                    $nominatimData.name,      # Nameは施設名
                    $basePoint.desc,          # Descは正確な住所(GSI由来)
                    $basePoint.extensions     # ExtensionsはGSI由来
                )
            }
        }
        catch {
            Write-Warning "Nominatim fetch failed: $_"
        }

        # Nominatim失敗または名前なしなら、住所解決の結果をそのまま返す
        return $basePoint
    }

    # =========================================================
    # 2. ResolveAddress: 座標 -> 住所のみ (GSI Reverse Geocoder)
    # =========================================================
    static [hashtable] ResolveAddress([hashtable]$Point) {
        $lat = $Point.lat
        $lon = $Point.lon
        $url = "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$lat&lon=$lon"

        try {
            $json = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            
            if (-not $json.results -or -not $json.results.muniCd) { return $Point }

            $muniCd5 = $json.results.muniCd
            $townName = if ($json.results.lv01Nm) { $json.results.lv01Nm } else { "" }

            if (-not [GeoService]::MunicipalitiesCache) { return $Point }
            
            $info = [GeoService]::MunicipalitiesCache['municipalities'] | Where-Object { $_.muniCd5 -eq $muniCd5 }
            if (-not $info) { return $Point }

            $extData = $info.Clone()
            $extData['town'] = $townName

            # Name: 町名(なければ市区町村名), Desc: フル住所
            $finalName = if ($townName) { $townName } else { $info.municipality }
            $finalDesc = "$($info.prefecture)$($info.municipality)$townName"
    
            # Name: 町名(なければ市区町村名), Desc: フル住所
            return [GeoService]::_CreatePoint(
                $lat, 
                $lon, 
                $finalName,
                $finalDesc,
                $extData
            )
        }
        catch {
            return $Point
        }
    }

    # =========================================================
    # 3. FetchCityTowns: 市区町村内の全町字 (Geolonia)
    # =========================================================
    static [hashtable[]] FetchCityTowns([hashtable]$Point) {
        $target = $Point
        # 情報不足なら住所解決を試みる
        if (-not $target.extensions.prefecture -or -not $target.extensions.municipality) {
            $target = [GeoService]::ResolveAddress($Point)
        }

        $pref = $target.extensions.prefecture
        $muni = $target.extensions.municipality

        if (-not $pref -or -not $muni) { return @() }

        $url = "https://geolonia.github.io/japanese-addresses/api/ja/$pref/$muni.json"
        
        try {
            $json = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            $results = @()
            foreach ($t in $json) {
                $extData = $target.extensions.Clone()
                $extData['town'] = $t.town

                $results += [GeoService]::_CreatePoint(
                    $t.lat,
                    $t.lng,
                    $t.town,
                    "$pref$muni$($t.town)",
                    $extData
                )
            }
            return $results
        }
        catch {
            return @()
        }
    }

    # =========================================================
    # 4. FetchAreaTowns: 周辺の町字ノード (Overpass API)
    # =========================================================
    static [hashtable[]] FetchAreaTowns([hashtable]$Point, [double]$Radius = 1000) {
        $lat = $Point.lat
        $lon = $Point.lon
        
        # Overpass QL: neighbourhood, quarter, locality を検索
        $query = @"
[out:json][timeout:30];
node["place"~"^(neighbourhood|quarter|locality)$"](around:$Radius,$lat,$lon);
out body;
"@
        $url = "https://overpass-api.de/api/interpreter"
        $maxRetries = 3

        for ($i = 0; $i -lt $maxRetries; $i++) {
            try {
                $json = Invoke-RestMethod -Uri $url -Method Post -Body $query -ContentType "text/plain" -ErrorAction Stop
                
                $results = @()
                if ($json.elements) {
                    foreach ($el in $json.elements) {
                        # タグに名前があるものだけ抽出
                        if ($el.tags -and $el.tags.name) {
                            $results += [GeoService]::_CreatePoint(
                                $el.lat, 
                                $el.lon, 
                                $el.tags.name, 
                                "Overpass Place", 
                                $null
                            )
                        }
                    }
                }
                return $results
            }
            catch {
                # 429 Too Many Requests などの場合は待機時間を増やす
                $delay = ($i + 1) * 2
                Write-Warning "Overpass API Retry $($i+1)/$maxRetries (Wait ${delay}s)..."
                Start-Sleep -Seconds $delay
            }
        }
        return @()
    }

    # =========================================================
    # 内部用: Nominatim Request with Rate Limit
    # =========================================================
    static [hashtable] _FetchNominatim([hashtable]$Point) {
        $cacheKey = "$($Point.lat)_$($Point.lon)"
        if ([GeoService]::NominatimCache.ContainsKey($cacheKey)) {
            return [GeoService]::NominatimCache[$cacheKey]
        }

        # Rate Limiting (1.1 sec wait policy)
        $now = [DateTime]::Now
        $diff = $now - [GeoService]::LastNominatimRequest
        if ($diff.TotalMilliseconds -lt 1100) {
            Start-Sleep -Milliseconds (1100 - $diff.TotalMilliseconds)
        }

        $url = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$($Point.lat)&lon=$($Point.lon)&zoom=18&addressdetails=1"
        
        # 簡易リトライ
        for ($i = 0; $i -lt 3; $i++) {
            try {
                [GeoService]::LastNominatimRequest = [DateTime]::Now
                $res = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "User-Agent" = "MyMapApp/1.0" } -ErrorAction Stop
                
                # キャッシュ保存
                [GeoService]::NominatimCache[$cacheKey] = $res
                return $res
            }
            catch {
                $delay = ($i + 1) * 2
                Start-Sleep -Seconds $delay
            }
        }
        return $null
    }
}
