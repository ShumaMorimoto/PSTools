class GeoService {
    # =========================================================
    # 設定・キャッシュ
    # =========================================================
    static [string] $MunicipalitiesPath = (Join-Path $script:ModuleRoot "data\municipalities.json")
    static [hashtable] $MunicipalitiesCache = $null
    static [hashtable] $NominatimCache = @{}
    
    # Nominatim用レート制限
    static [DateTime] $LastNominatimRequest = [DateTime]::MinValue

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
    # 1. Resolve: 位置情報に近くの拠点（name, desc）を割り当てる
    # =========================================================
    static [hashtable] Resolve([hashtable]$Point) {
        # 1. まず住所情報を補完 (自治体情報を付与)
        $null = [GeoService]::ResolveAddress($Point)

        # 2. Nominatimで詳細な場所名を取りに行く
        try {
            $nominatimData = [GeoService]::_FetchNominatim($Point)

            if ($nominatimData -and $nominatimData.name) {
                # 拠点名が見つかれば name を更新
                $Point.name = "$($nominatimData.name)"
            }
            elseif (-not $Point.name -and $Point.extensions.municipality) {
                # 名前がなく自治体情報があるなら、町名または市区町村名で補完
                $Point.name = if ($Point.extensions.town) { $Point.extensions.town } else { $Point.extensions.municipality }
            }
        }
        catch {
            Write-Warning "Nominatim fetch failed: $_"
        }

        return $Point
    }

    # =========================================================
    # 2. ResolveAddress: 位置情報に自治体情報を付与する
    # =========================================================
    static [hashtable] ResolveAddress([hashtable]$Point) {
        $lat = $Point.lat
        $lon = $Point.lon
        $url = "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$lat&lon=$lon"

        try {
            $json = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            
            if (-not $json.results -or -not $json.results.muniCd) { return $Point }

            $muniCd5 = $json.results.muniCd
            $townName = if ($json.results.lv01Nm) { "$($json.results.lv01Nm)" } else { "" }

            if (-not [GeoService]::MunicipalitiesCache) { return $Point }
            
            $info = [GeoService]::MunicipalitiesCache['municipalities'] | Where-Object { $_.muniCd5 -eq $muniCd5 }
            if (-not $info) { return $Point }

            # extensions の確保と補完
            if (-not $Point.ContainsKey('extensions')) { $Point['extensions'] = @{} }
            
            $Point.extensions['muniCd5']     = "$muniCd5"
            $Point.extensions['prefecture']  = "$($info.prefecture)"
            $Point.extensions['municipality']= "$($info.municipality)"
            $Point.extensions['town']        = "$townName"

            # desc (フル住所) の補完
            $Point.desc = "$($info.prefecture)$($info.municipality)$townName"
            
            # name が空なら暫定的に地名をセット
            if (-not $Point.name) {
                $Point.name = if ($townName) { $townName } else { "$($info.municipality)" }
            }
        }
        catch {
            Write-Warning "GSI Resolve failed: $_"
        }
        return $Point
    }

    # =========================================================
    # 3. FetchCityTowns: 市区町村内の全町字 (Geolonia)
    # =========================================================
    static [hashtable[]] FetchCityTowns([hashtable]$Point) {
        $target = $Point
        if (-not $target.extensions.prefecture -or -not $target.extensions.municipality) {
            # 元のオブジェクトを壊さないよう、一時的なクローンで解決を試みる
            $temp = $Point.Clone()
            $target = [GeoService]::ResolveAddress($temp)
        }

        $pref = $target.extensions.prefecture
        $muni = $target.extensions.municipality
        if (-not $pref -or -not $muni) { return @() }

        $url = "https://geolonia.github.io/japanese-addresses/api/ja/$pref/$muni.json"
        
        try {
            $json = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            $results = @()
            foreach ($t in $json) {
                # 新しいハッシュテーブルとして町字リストを作成
                $results += @{
                    lat  = [double]$t.lat
                    lon  = [double]$t.lng
                    name = "$($t.town)"
                    desc = "$pref$muni$($t.town)"
                    extensions = @{
                        muniCd5      = "$($target.extensions.muniCd5)"
                        prefecture   = "$pref"
                        municipality = "$muni"
                        town         = "$($t.town)"
                    }
                }
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
        
        $query = "[out:json][timeout:30];node['place'~'^(neighbourhood|quarter|locality)$'](around:$Radius,$lat,$lon);out body;"
        $url = "https://overpass-api.de/api/interpreter"
        $maxRetries = 3

        for ($i = 0; $i -lt $maxRetries; $i++) {
            try {
                $json = Invoke-RestMethod -Uri $url -Method Post -Body $query -ContentType "text/plain" -ErrorAction Stop
                
                $results = @()
                if ($json.elements) {
                    foreach ($el in $json.elements) {
                        if ($el.tags -and $el.tags.name) {
                            $results += @{
                                lat  = [double]$el.lat
                                lon  = [double]$el.lon
                                name = "$($el.tags.name)"
                                desc = "Overpass Place"
                                extensions = @{}
                            }
                        }
                    }
                }
                return $results
            }
            catch {
                $delay = ($i + 1) * 2
                Start-Sleep -Seconds $delay
            }
        }
        return @()
    }

    # --- 内部用: Nominatim (Rate Limit付き) ---
    static [hashtable] _FetchNominatim([hashtable]$Point) {
        $cacheKey = "$($Point.lat)_$($Point.lon)"
        if ([GeoService]::NominatimCache.ContainsKey($cacheKey)) {
            return [GeoService]::NominatimCache[$cacheKey]
        }

        $now = [DateTime]::Now
        $diff = $now - [GeoService]::LastNominatimRequest
        if ($diff.TotalMilliseconds -lt 1100) {
            Start-Sleep -Milliseconds (1100 - $diff.TotalMilliseconds)
        }

        $url = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$($Point.lat)&lon=$($Point.lon)&zoom=18&addressdetails=1"
        
        for ($i = 0; $i -lt 3; $i++) {
            try {
                [GeoService]::LastNominatimRequest = [DateTime]::Now
                $res = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "User-Agent" = "MyMapApp/1.0" } -ErrorAction Stop
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