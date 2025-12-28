class GeoService {

    # =========================================================
    # 共通：trkpt 互換フォーマット生成
    # =========================================================
    static [hashtable] _MakePoint(
        [double]$Lat,
        [double]$Lon,
        [string]$Name,
        [hashtable]$Ext
    ) {
        return @{
            lat        = $Lat
            lon        = $Lon
            name       = $Name
            extensions = $Ext
        }
    }

    # =========================================================
    # municipalities.json のパス（あとで変更可能）
    # =========================================================
    static [string] $MunicipalitiesPath = "D:\tool\Repository\PSTools\開発中\GPX4\municipalities.json"
    static $MunicipalitiesCache = $null

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
                name            = $m.name
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
    # municipalities.json のロード
    # =========================================================
    static [object] _LoadMunicipalities() {
        if ($null -ne [GeoService]::MunicipalitiesCache) {
            return [GeoService]::MunicipalitiesCache
        }
        $path = [GeoService]::MunicipalitiesPath
        if (-not (Test-Path $path)) {
            throw "municipalities.json が見つかりません: $path"
        }
        $json = Get-Content -Raw -Path $path | ConvertFrom-Json
        [GeoService]::MunicipalitiesCache = $json
        return $json
    }

    # =========================================================
    # 1. SearchPlace（Nominatim）
    # キーワード → 複数候補
    # country_code を extensions に含める
    # =========================================================
    static [hashtable[]] SearchPlace([string]$Keyword) {

        $url = "https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&q=$([uri]::EscapeDataString($Keyword))"

        $json = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "User-Agent" = "GeoService" }

        $results = @()

        foreach ($item in $json) {

            $ext = @{
                countryCode  = $item.address.country_code
                municipality = $item.address.city ?? $item.address.town ?? $item.address.village
                prefecture   = $item.address.state
            }

            $results += [GeoService]::_MakePoint(
                [double]$item.lat,
                [double]$item.lon,
                $item.display_name,
                $ext
            )
        }

        return $results
    }

    # =========================================================
    # 2. ResolveAddress（GSI Reverse + municipalities.json）
    # 座標 → muniInfo（最終形）
    # =========================================================
    static [hashtable] ResolveAddress([hashtable]$Point) {

        $lat = $Point.lat
        $lon = $Point.lon

        # 1. GSI Reverse → muniCd5
        $url = "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$lat&lon=$lon"
        $json = Invoke-RestMethod -Uri $url -Method Get

        $muniCd5 = $json.results.muniCd
        $town = $json.results.lv01Nm

        # 2. municipalities.json から muniInfo を取得
        $muniData = [GeoService]::_LoadMunicipalities()
        $muniInfo = $muniData.municipalities | Where-Object { $_.muniCd5 -eq $muniCd5 }

        if (-not $muniInfo) {
            return $null
        }

        # muniInfo は JS と同じ構造：
        # {
        #   name: "横須賀市",
        #   prefecture: "神奈川県",
        #   muniCd5: "14201",
        #   ...
        # }

        $ext = @{
            prefecture   = $muniInfo.prefecture
            municipality = $muniInfo.name
            muniCd5      = $muniInfo.muniCd5
            town         = $town
            block        = ""   # GSI は丁目まで
        }

        return [GeoService]::_MakePoint(
            $lat,
            $lon,
            "$($ext.town)$($ext.block)",
            $ext
        )
    }

    # =========================================================
    # 3. QueryTowns（Geolonia）
    # muniCd5 ではなく prefecture / municipality 名で取得
    # =========================================================
    static [hashtable[]] QueryTowns([hashtable]$Trkpt) {

        $pref = $Trkpt.extensions.prefecture
        $muni = $Trkpt.extensions.municipality

        $url = "https://geolonia.github.io/japanese-addresses/api/ja/$pref/$muni.json"

        try {
            $json = Invoke-RestMethod -Uri $url -Method Get
        }
        catch {
            return @()
        }

        $results = @()

        foreach ($town in $json) {

            $results += [GeoService]::_MakePoint(
                [double]$town.lat,
                [double]$town.lng,
                $town.name,
                @{
                    prefecture   = $pref
                    municipality = $muni
                    muniCd5      = $Trkpt.extensions.muniCd5
                    town         = $town.name
                }
            )
        }

        return $results
    }

    # =========================================================
    # 4. QueryArea（Overpass）
    # 中心座標 + 半径 → 町字一覧
    # =========================================================
    static [hashtable[]] QueryArea([hashtable]$Center, [double]$RadiusMeters) {

        $lat = $Center.lat
        $lon = $Center.lon

        $query = @"
[out:json];
node(around:$RadiusMeters,$lat,$lon)["place"~"^(neighbourhood|quarter)$"];
out body;
"@

        $url = "https://overpass-api.de/api/interpreter"
        $json = Invoke-RestMethod -Uri $url -Method Post -Body $query -ContentType "text/plain"

        $results = @()

        foreach ($node in $json.elements) {

            $name = $node.tags.name ?? "unknown"

            # ★自治体情報は入れない
            $ext = @{
                place = $node.tags.place
                osmId = $node.id
            }

            $results += [GeoService]::_MakePoint(
                [double]$node.lat,
                [double]$node.lon,
                $name,
                $ext
            )
        }

        return $results
    }
}

# Requires -Modules Pester

Describe "GeoService" {

    BeforeAll {
        Mock Invoke-RestMethod {
            param($Uri, $Method, $Body, $ContentType)

            switch -Wildcard ($Uri) {

                # -----------------------------
                # SearchPlace (Nominatim)
                # -----------------------------
                "*nominatim*" {
                    return @(
                        @{
                            lat          = "35.281"
                            lon          = "139.672"
                            display_name = "横須賀市, 神奈川県, 日本"
                            address      = @{
                                country_code = "jp"
                                state        = "神奈川県"
                                city         = "横須賀市"
                            }
                        }
                    )
                }

                # -----------------------------
                # ResolveAddress (GSI Reverse)
                # -----------------------------
                "*LonLatToAddress*" {
                    return @{
                        results = @{
                            muniCd = "14201"
                            lv01Nm = "汐入町"
                        }
                    }
                }

                # -----------------------------
                # QueryTowns (Geolonia)
                # -----------------------------
                "*geolonia*" {
                    return @(
                        @{ name = "汐入町"; lat = 35.281; lng = 139.672 },
                        @{ name = "本町"; lat = 35.29; lng = 139.66 }
                    )
                }

                # -----------------------------
                # QueryArea (Overpass)
                # -----------------------------
                "*overpass*" {
                    return @{
                        elements = @(
                            @{
                                id   = 123
                                lat  = 35.281
                                lon  = 139.672
                                tags = @{
                                    name  = "汐入町"
                                    place = "neighbourhood"
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    # ---------------------------------------------------------
    # 1. SearchPlace
    # ---------------------------------------------------------
    It "SearchPlace returns hashtable[] with correct format" {
        $results = [GeoService]::SearchPlace("横須賀市")

        ($results -is [array]) | Should Be $true
        $results.Count | Should Be 1

        $p = $results[0]
        $p.lat | Should Be 35.281
        $p.lon | Should Be 139.672

        $p.extensions.countryCode | Should Be "jp"
        $p.extensions.municipality | Should Be "横須賀市"
        $p.extensions.prefecture | Should Be "神奈川県"
    }

    # ---------------------------------------------------------
    # 2. ResolveAddress
    # ---------------------------------------------------------
    It "ResolveAddress returns muniInfo-based hashtable" {
        $point = @{ lat = 35.281; lon = 139.672 }
        $result = [GeoService]::ResolveAddress($point)

        $result.lat | Should Be 35.281
        $result.lon | Should Be 139.672

        $ext = $result.extensions
        $ext.muniCd5 | Should Be "14201"
        $ext.municipality | Should Be "横須賀市"
        $ext.prefecture | Should Be "神奈川県"
        $ext.town | Should Be "汐入町"
    }

    # ---------------------------------------------------------
    # 3. QueryTowns
    # ---------------------------------------------------------
    It "QueryTowns returns hashtable[] with correct town info" {
        $muni = @{
            prefecture   = "神奈川県"
            municipality = "横須賀市"
            muniCd5      = "14201"
        }

        $towns = [GeoService]::QueryTowns($muni)

        $towns.Count | Should Be 2

        $towns[0].name | Should Be "汐入町"
        $towns[0].extensions.municipality | Should Be "横須賀市"
        $towns[0].extensions.prefecture | Should Be "神奈川県"
    }

    # ---------------------------------------------------------
    # 4. QueryArea
    # ---------------------------------------------------------
    It "QueryArea returns hashtable[] without municipality/prefecture" {
        $center = @{
            lat        = 35.281
            lon        = 139.672
            extensions = @{
                municipality = "横須賀市"
                prefecture   = "神奈川県"
            }
        }

        $towns = [GeoService]::QueryArea($center, 500)

        $towns.Count | Should Be 1

        $keys = $towns[0].extensions.Keys

        # Pester 3 のバグ回避：-contains を使う
        ($keys -contains "place") | Should Be $true
        ($keys -contains "municipality") | Should Be $false
        ($keys -contains "prefecture") | Should Be $false
    }
}
