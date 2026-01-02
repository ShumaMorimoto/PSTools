#モジュールルートの設定
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# RunApp を絶対パスで読み込む
Import-Module "D:\tool\Repository\PSTools\RunApp" -Force

# ─── DLL 読み込み ───
Add-Type -Path "$PSScriptRoot\lib\TspSolverLib.dll" 

# ─── クラス定義 ───
class GPXService {
    hidden static $creator = "GPXDocument クラス"
    hidden static [string] $GpxNamespace = "http://www.topografix.com/GPX/1/1"
    #    hidden static [string] $xsdPath = (Join-Path $script:ModuleRoot "config/gpx.xsd")
    hidden static [string] $xsdPath = "D:\tool\Repository\PSTools\RouteOptimizer\config\gpx.xsd"
    static [hashtable] $TypeMap = @{}

    [xml] $Doc
    [hashtable] $Model

    static hidden [void] LoadSchema() {
        $schemaSet = [System.Xml.Schema.XmlSchemaSet]::new()
        $schemaSet.Add([GPXService]::GpxNamespace, [GPXService]::xsdPath) | Out-Null
        $schemaSet.Compile()

        $simpleTypes = @{}
        # simpleType の継承関係を収集
        foreach ($schema in $schemaSet.Schemas()) {
            foreach ($item in $schema.Items) {
                if ($item -is [System.Xml.Schema.XmlSchemaSimpleType]) {
                    $simpleTypes[$item.Name] = $item.Content.BaseTypeName.Name
                }
            }
        }
        function ResolveBase([string]$type) {
            while ($simpleTypes.ContainsKey($type)) {
                $type = $simpleTypes[$type]
            }
            return $type
        }
        # element / attribute を TypeMap に登録
        foreach ($schema in $schemaSet.Schemas()) {
            foreach ($item in $schema.Items) {
                # element
                if ($item -is [System.Xml.Schema.XmlSchemaElement]) {
                    $typeName = $item.SchemaTypeName.Name
                    $base = $simpleTypes.ContainsKey($typeName) ? (ResolveBase $typeName) : $typeName
                    [GPXService]::TypeMap[$item.Name] = @{
                        BaseType    = $base
                        IsAttribute = $false
                    }
                }
                # complexType の属性
                if ($item -is [System.Xml.Schema.XmlSchemaComplexType]) {
                    foreach ($attr in $item.Attributes) {
                        $typeName = $attr.SchemaTypeName.Name
                        $base = $simpleTypes.ContainsKey($typeName) ? (ResolveBase $typeName) : $typeName

                        [GPXService]::TypeMap[$attr.Name] = @{
                            BaseType    = $base
                            IsAttribute = $true
                        }
                    }
                }
            }
        }
    }

    static GPXService() {
        [GPXService]::LoadSchema()
    }

    GPXService() {
        $this.Doc = New-Object System.Xml.XmlDocument
        $root = $this.Doc.CreateElement("gpx", [GPXService]::GpxNamespace)
        $this.Doc.AppendChild($root) | Out-Null

        $this.Model = $this.NormalizeModel($null)
    }

    GPXService([hashtable] $initialModel) {
        $this.Doc = New-Object System.Xml.XmlDocument
        $root = $this.Doc.CreateElement("gpx", [GPXService]::GpxNamespace)
        $this.Doc.AppendChild($root) | Out-Null

        $this.Model = $this.NormalizeModel($initialModel)
    }


    # ----------------------------
    # Model Operations
    # ----------------------------
    [void] SetModel([hashtable] $model) {
        $this.Model = $this.NormalizeModel($model)
    }

    [hashtable] GetModel() {
        return $this.Model
    }

    # ----------------------------
    # XML → Model
    # ----------------------------
    [void] LoadFromXml([string] $xmlString) {
        $xml = [xml]$xmlString
        $this.Model = $this.XmlToJson($xml.DocumentElement)
    }

    # ----------------------------
    # Model → XML
    # ----------------------------
    [string] ToXml() {
        if (-not $this.Model) { return "" }

        $newDoc = New-Object System.Xml.XmlDocument
        $root = $this.CreateElementFromObject("gpx", $this.Model, $newDoc)
        $root.SetAttribute("version", "1.1")
        $root.SetAttribute("xmlns", [GPXService]::GpxNamespace)

        $newDoc.AppendChild($root) | Out-Null
        return $newDoc.OuterXml
    }
    # ----------------------------
    # Model → JSON
    # ----------------------------
    [string] ToJson() {
        if (-not $this.Model) { return "" }
        return ConvertTo-Json -depth 10 $this.Model
    }

    [void] Load([string] $path) {
        if (-not (Test-Path $path)) {
            throw "GPX file not found: $path"
        }

        $xmlString = Get-Content -Path $path -Raw
        $this.LoadFromXml($xmlString)
    }

    [void] Save([string] $path) {
        $xml = $this.ToXml()
        if (-not $xml) {
            throw "GPX model is empty. Nothing to save."
        }

        $xml | Out-File -FilePath $path -Encoding utf8
    }

    # ----------------------------
    # JSON → XML Element
    # ----------------------------
    [System.Xml.XmlElement] CreateElementFromObject(
        [string] $name,
        [object] $obj,
        [xml] $doc
    ) {
        $elem = $doc.CreateElement($name, [GPXService]::GpxNamespace)

        if (-not $obj) { return $elem }

        foreach ($key in $obj.Keys) {
            if ($key.StartsWith("_")) { continue }

            $value = $obj[$key]

            if ($value -is [hashtable]) {
                $child = $this.CreateElementFromObject($key, $value, $doc)
                $elem.AppendChild($child) | Out-Null
            }
            elseif ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                foreach ($item in $value) {
                    if ($item -is [hashtable]) {
                        $child = $this.CreateElementFromObject($key, $item, $doc)
                        $elem.AppendChild($child) | Out-Null
                    }
                    else {
                        $child = $doc.CreateElement($key, [GPXService]::GpxNamespace)
                        $child.InnerText = "$item"
                        $elem.AppendChild($child) | Out-Null
                    }
                }
            }
            else {
                # 属性扱い（JS版の TypeMap を簡略化）
                if ($key -in @("lat", "lon", "version", "creator", "id", "href", "maxlat", "maxlon", "minlat", "minlon")) {
                    $elem.SetAttribute($key, "$value")
                }
                else {
                    $child = $doc.CreateElement($key, [GPXService]::GpxNamespace)
                    $child.InnerText = "$value"
                    $elem.AppendChild($child) | Out-Null
                }
            }
        }

        return $elem
    }

    # ----------------------------
    # XML Element → JSON
    # ----------------------------
    [hashtable] XmlToJson([System.Xml.XmlElement] $elem) {
        $obj = @{}

        # Attributes
        foreach ($attr in $elem.Attributes) {
            if ($attr.Name -eq "xmlns") { continue }
            $obj[$attr.Name] = $attr.Value
        }

        # Child elements
        foreach ($child in $elem.ChildNodes) {
            if ($child.NodeType -ne "Element") { continue }

            $name = $child.LocalName

            if (-not $obj.ContainsKey($name)) {
                $obj[$name] = @()
            }

            $obj[$name] += $this.XmlToJson($child)
        }

        # 単一要素は配列 → 値に変換
        foreach ($key in @($obj.Keys)) {
            if ($obj[$key].Count -eq 1) {
                $obj[$key] = $obj[$key][0]
            }
        }

        return $obj
    }

    # ----------------------------
    # Track Point Operations
    # ----------------------------
    [object[]] GetTrkpts() {
        return $this.Model.trk.trkseg.trkpt
    }

    [void] SetTrkpts([object[]] $pts) {
        $this.Model.trk.trkseg.trkpt = $pts
    }

    [void] AppendTrkpt([hashtable] $trkpt) {
        if (-not $trkpt.lat -or -not $trkpt.lon) {
            throw "lat and lon are required"
        }
        $this.Model.trk.trkseg.trkpt += $trkpt
    }
    # ----------------------------
    # Waypoint Operations
    # ----------------------------
    [object[]] GetWpts() {
        return $this.Model.wpt
    }

    [void] SetWpts([object[]] $wpts) {
        $this.Model.wpt = $wpts
    }

    [void] AppendWpt([hashtable] $wpt) {
        if (-not $wpt.lat -or -not $wpt.lon) {
            throw "lat and lon are required"
        }
        $this.Model.wpt += $wpt
    }

    [void] RemoveTrkpt([hashtable] $pt) {
        $list = $this.Model.trk.trkseg.trkpt
        $this.Model.trk.trkseg.trkpt = $list | Where-Object { $_ -ne $pt }
    }

    # ----------------------------
    # Internal Utilities
    # ----------------------------
    [hashtable] NormalizeModel([hashtable] $model) {
        if (-not $model) {
            return @{
                version  = "1.1"
                creator  = "MapSelector"
                metadata = @{
                    time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
                trk      = @{
                    trkseg = @{
                        trkpt = @()
                    }
                }
            }
        }
        if (-not $model.ContainsKey("trk")) {
            $model.trk = @{ trkseg = @{ trkpt = @() } }
        }
        if (-not $model.trk.ContainsKey("trkseg")) {
            $model.trk.trkseg = @{ trkpt = @() }
        }
        if (-not ($model.trk.trkseg.trkpt -is [System.Collections.IEnumerable])) {
            $model.trk.trkseg.trkpt = @($model.trk.trkseg.trkpt)
        }

        # 既存モデルに metadata が無い場合だけ time を補完
        if (-not $model.ContainsKey("metadata")) {
            $model.metadata = @{ time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") }
        }
        elseif (-not $model.metadata.ContainsKey("time")) {
            $model.metadata.time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        return $model
    }

    static [hashtable[]] NormalizeData($input) {
        # 位置指定なら trkpt 1件のリストにする
        if ($input -is [hashtable] -and $input.lat -and $input.lon) {
            $pt = [GeoService]::ResolveAddress($input)
            return @($pt)
        }

        # キーワード抽出
        $keyword = ($input -is [hashtable]) ? $input.keyword : $input

        # キーワード検索 → trkpt 候補
        return [GeoService]::SearchPlace($keyword)
    }
    static [GPXService] Search($input) {
        $gpx = [GPXService]::new()

        # 1. keyword を metadata に保存
        if ($input -is [string]) {
            $gpx.Model.metadata.keywords = $input
        }
        elseif ($input.keyword) {
            $gpx.Model.Metadata.keywords = $input.keyword
        }

        # 3. NormalizeData
        $pts = [GPXService]::NormalizeData($input)
        switch ($pts.Count) {
            0 {}
            1 {
                $pt = $pts[0]
                $gpx.Model.metadata.name = $pt.name
                $gpx.Model.metadata.desc = $pt.desc
                $gpx.Model.metadata.extensions = $pt.extensions
                $gpx.SetTrkpts(@($pt))
            }
            default {
                $gpx.SetWpts($pts)
            }
        }
        return $gpx
    }
    static [GPXService] FromCityTowns($input) {
        $gpx = [GPXService]::new()
        if ($input -is [string]) {
            $gpx.Model.metadata.keywords = $input
        }
        elseif ($input.keyword) {
            $gpx.Model.metadata.keywords = $input.keyword
        }

        $pts = [GPXService]::NormalizeData($input)
        switch ($pts.Count) {
            0 {}
            1 {
                $pt = $pts[0]
                $gpx.Model.metadata.name = $pt.name
                $gpx.Model.metadata.desc = $pt.desc
                $gpx.Model.metadata.extensions = $pt.extensions

                $towns = [GeoService]::QueryTowns($pt)
                $gpx.SetTrkpts($towns)
            }
            default {
                $gpx.SetWpts($pts)
            }
        }
        return $gpx
    }
    static [GPXService] FromAreaTowns($input) {
        $gpx = [GPXService]::new()

        if ($input -is [string]) {
            $gpx.Model.metadata.keywords = $input
        }
        elseif ($input.keyword) {
            $gpx.Model.metadata.keywords = $input.keyword
        }

        $pts = [GPXService]::NormalizeData($input)
        switch ($pts.Count) {
            0 { }
            1 {
                $pt = $pts[0]
                $gpx.Model.metadata.name = $pt.name
                $gpx.Model.metadata.desc = $pt.desc
                $gpx.Model.metadata.extensions = $pt.extensions

                $areas = [GeoService]::QueryArea($pt)
                $gpx.SetTrkpts($areas)
            }
            default {
                $gpx.SetWpts($pts)
            }
        }

        return $gpx
    }
}
class GeoService {
    # =========================================================
    # municipalities.json のパス（あとで変更可能）
    # =========================================================
    static [string] $MunicipalitiesPath = (Join-Path $script:ModuleRoot "data\municipalities.json")
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


# ─── 関数読み込み ───
foreach ($folder in @('Common', 'Extensions', 'Private', 'Public')) {
    if (Test-Path "$PSScriptRoot\$folder") {
        Get-ChildItem "$PSScriptRoot\$folder\*.ps1" | ForEach-Object {
            . $_.FullName
        }
    }
}

# ─── 公開関数 ───
$publicFunctions = @()
if (Test-Path "$PSScriptRoot\Public") {
    $publicFunctions = Get-ChildItem "$PSScriptRoot\Public\*.ps1" | ForEach-Object {
        [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    }
}
Export-ModuleMember -Function $publicFunctions

# ─── モジュール初期化 ───
Enable-ModuleSettings
