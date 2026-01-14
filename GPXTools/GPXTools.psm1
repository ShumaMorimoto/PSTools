#モジュールルートの設定
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─── DLL 読み込み ───
Add-Type -Path "$PSScriptRoot\lib\TspSolverLib.dll" 

# ─── クラス定義 ───
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
class XmlJsonBase : IDisposable {
    hidden [string] $Namespace
    hidden [string] $RootName
    hidden static [hashtable] $GlobalTypeMap = @{}

    [hashtable] $Model

    # --- Constructor ---
    XmlJsonBase([string]$ns, [string]$root, [string]$xsdPath) {
        $this.Namespace = $ns
        $this.RootName = $root
        
        if (-not [XmlJsonBase]::GlobalTypeMap.ContainsKey($ns)) {
            [XmlJsonBase]::StaticLoadSchema($ns, $xsdPath)
        }
    }

    # --- Hash 連携 (Model操作) ---
    [void] LoadModel([hashtable]$hash) {
        if ($null -eq $hash) { throw "Model cannot be null." }
        $this.Model = $hash
    }

    [hashtable] ToModel() {
        return $this.Model
    }

    # --- XML 連携 ---
    [void] Load([string]$path) {
        if (-not (Test-Path $path)) { throw "File not found: $path" }
        $this.LoadXml((Get-Content $path -Raw))
    }

    [void] LoadXml([string]$xmlString) {
        $xml = [xml]$xmlString
        $this.Model = $this.XmlToHash($xml.DocumentElement)
    }

    [void] Save([string]$path) {
        $doc = New-Object System.Xml.XmlDocument
        $doc.LoadXml($this.ToXml())
        
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Indent = $true
        $settings.IndentChars = "  "
        $settings.Encoding = [System.Text.Encoding]::UTF8

        # ファイルを生成する Writer を作成
        $writer = [System.Xml.XmlWriter]::Create($path, $settings)
        try {
            $doc.Save($writer)
            # 確実にバッファを書き出す
            $writer.Flush() 
        }
        finally {
            # 最後に必ず閉じる。これで 0KB は解消されます。
            $writer.Dispose()
        }
    }

    [string] ToXml() {
        $doc = New-Object System.Xml.XmlDocument
        $decl = $doc.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $doc.AppendChild($decl) | Out-Null

        $root = $doc.CreateElement($this.RootName, $this.Namespace)
        $map = [XmlJsonBase]::GlobalTypeMap[$this.Namespace]

        if ($this.Model -is [hashtable]) {
            foreach ($key in $this.Model.Keys) {
                $val = $this.Model[$key]
                if ($null -eq $val) { continue }

                if (($map.ContainsKey($key) -and $map[$key].IsAttribute) -or ($key -in @("version", "creator"))) {
                    $root.SetAttribute($key, [string]$val)
                }
                else {
                    if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                        foreach ($item in $val) { $root.AppendChild($this.HashToXml($key, $item, $doc)) | Out-Null }
                    }
                    else {
                        $root.AppendChild($this.HashToXml($key, $val, $doc)) | Out-Null
                    }
                }
            }
        }
        
        $doc.AppendChild($root) | Out-Null
        return $doc.OuterXml
    }

    # --- JSON 連携 ---
    [void] LoadJson([string]$jsonString) { $this.Model = $jsonString | ConvertFrom-Json -AsHashtable }
    [string] ToJson() { return ConvertTo-Json -Depth 10 $this.Model }

    # --- スキーマ解析ロジック ---
    static [void] StaticLoadSchema([string]$ns, [string]$xsdPath) {
        if (-not (Test-Path $xsdPath)) { 
            [XmlJsonBase]::GlobalTypeMap[$ns] = @{}
            return 
        }
        $map = @{}
        $schemaSet = [System.Xml.Schema.XmlSchemaSet]::new()
        $schemaSet.Add($ns, $xsdPath) | Out-Null
        $schemaSet.Compile()
        $simpleTypes = @{}
        foreach ($schema in $schemaSet.Schemas()) {
            foreach ($item in $schema.Items) {
                if ($item -is [System.Xml.Schema.XmlSchemaSimpleType]) { $simpleTypes[$item.Name] = $item.Content.BaseTypeName.Name }
            }
        }
        foreach ($schema in $schemaSet.Schemas()) {
            foreach ($item in $schema.Items) {
                if ($item -is [System.Xml.Schema.XmlSchemaElement]) {
                    $map[$item.Name] = @{ BaseType = [XmlJsonBase]::StaticResolveBase($item.SchemaTypeName.Name, $simpleTypes); IsAttribute = $false }
                }
                if ($item -is [System.Xml.Schema.XmlSchemaComplexType]) {
                    foreach ($attr in $item.Attributes) {
                        $map[$attr.Name] = @{ BaseType = [XmlJsonBase]::StaticResolveBase($attr.SchemaTypeName.Name, $simpleTypes); IsAttribute = $true }
                    }
                }
            }
        }
        [XmlJsonBase]::GlobalTypeMap[$ns] = $map
    }

    static [string] StaticResolveBase([string]$type, [hashtable]$stMap) {
        while ($stMap.ContainsKey($type)) { $type = $stMap[$type] }
        return $type
    }

    static [void] StaticAddMapping([string]$ns, [string]$key, [string]$type, [bool]$isAttr) {
        if (-not [XmlJsonBase]::GlobalTypeMap.ContainsKey($ns)) { [XmlJsonBase]::GlobalTypeMap[$ns] = @{} }
        [XmlJsonBase]::GlobalTypeMap[$ns][$key] = @{ BaseType = $type; IsAttribute = $isAttr }
    }

    # --- 内部変換コアロジック ---
    hidden [object] CastValue([string]$key, [string]$value) {
        if ([string]::IsNullOrWhiteSpace($value)) { return $value }
        $map = [XmlJsonBase]::GlobalTypeMap[$this.Namespace]
        if (-not $map.ContainsKey($key)) { return $value }
        $targetType = $map[$key].BaseType
        try {
            $result = switch ($targetType) {
                "double" { [double]$value }
                "decimal" { [decimal]$value }
                "boolean" { [System.Xml.XmlConvert]::ToBoolean($value.ToLower()) }
                "dateTime" { [DateTime]$value }
                Default { $value }
            }
            return $result
        }
        catch { return $value }
    }

    hidden [object] XmlToHash([System.Xml.XmlElement]$elem) {
        $node = @{}
        $hasContent = $false
        $simpleValue = $null
        foreach ($attr in $elem.Attributes) {
            if ($attr.Name -match "xmlns|xsi") { continue }
            $node[$attr.Name] = $this.CastValue($attr.Name, $attr.Value)
            $hasContent = $true
        }
        foreach ($child in $elem.ChildNodes) {
            if ($child.NodeType -eq "Element") {
                $hasContent = $true
                $name = $child.LocalName
                $val = $this.XmlToHash($child)
                if (-not $node.ContainsKey($name)) { $node[$name] = [System.Collections.ArrayList]@($val) }
                else { [void]$node[$name].Add($val) }
            }
            elseif ($child.NodeType -match "Text|CDATA") {
                $textValue = $this.CastValue($elem.LocalName, $child.Value)
                if (-not $hasContent) { $simpleValue = $textValue }
                else { $node["#text"] = $textValue }
            }
        }
        if ($hasContent) {
            foreach ($key in @($node.Keys)) {
                if ($node[$key] -is [System.Collections.ArrayList] -and $node[$key].Count -eq 1) {
                    if (-not $this.IsArrayElement($key)) { $node[$key] = $node[$key][0] }
                }
            }
        }
        
        # 修正：PowerShell 5.1互換のif/else
        if (-not $hasContent -and $null -ne $simpleValue) {
            return $simpleValue
        }
        return $node
    }

    hidden [System.Xml.XmlElement] HashToXml([string]$name, [object]$obj, [xml]$doc) {
        $elem = $doc.CreateElement($name, $this.Namespace)
        $map = [XmlJsonBase]::GlobalTypeMap[$this.Namespace]
        if ($obj -is [hashtable]) {
            foreach ($key in $obj.Keys) {
                if ($key -eq "#text") { $elem.InnerText = [string]$obj[$key]; continue }
                $val = $obj[$key]
                if ($map.ContainsKey($key) -and $map[$key].IsAttribute) { $elem.SetAttribute($key, [string]$val) }
                elseif ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                    foreach ($item in $val) { $elem.AppendChild($this.HashToXml($key, $item, $doc)) | Out-Null }
                }
                else { $elem.AppendChild($this.HashToXml($key, $val, $doc)) | Out-Null }
            }
        }
        else { $elem.InnerText = [string]$obj }
        return $elem
    }

    hidden [bool] IsArrayElement([string]$name) {
        return $name -in @("trk", "trkseg", "trkpt", "wpt", "rte", "rtept", "link")
    }

    [void] Dispose() {}
}
class GPXService : XmlJsonBase {
    hidden static [string] $ns = "http://www.topografix.com/GPX/1/1"
    hidden static [string] $xsd = ""

    # --- スタティックコンストラクタ (型情報の定義) ---
    static GPXService() {
        # 1. 標準XSDをロード
        [XmlJsonBase]::StaticLoadSchema([GPXService]::ns, [GPXService]::xsd)
        
        # 2. 型キャストを確実にするための明示的なマッピング追加
        [XmlJsonBase]::StaticAddMapping([GPXService]::ns, "lat", "double", $true)
        [XmlJsonBase]::StaticAddMapping([GPXService]::ns, "lon", "double", $true)
        [XmlJsonBase]::StaticAddMapping([GPXService]::ns, "muitiRoute", "string", $true)
    }

    # --- コンストラクタ ---

    # パターン1: デフォルト（新規作成用・雛形あり）
    GPXService() : base([GPXService]::ns, "gpx", [GPXService]::xsd) {
        $this.InitializeModel()
    }

    # パターン2: 既存のハッシュテーブルから生成 (LoadModel を利用)
    GPXService([hashtable]$model) : base([GPXService]::ns, "gpx", [GPXService]::xsd) {
        $this.LoadModel($model)
    }

    # --- ファクトリ ---
    static [GPXService] FromFile([string]$path) {
        $inst = [GPXService]::new()
        $inst.Load($path) # Base の Load を利用
        return $inst
    }

    # --- 内部状態の管理 ---

    # 初期雛形を Model にロードする
    [void] InitializeModel() {
        $this.LoadModel(@{
                version  = "1.1"
                creator  = "GPX Service"
                metadata = @{ time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") }
                trk      = @{ trkseg = @{ trkpt = [System.Collections.ArrayList]@() } }
            })
    }

    # --- データの取り出し (ToModel) ---
    [hashtable] ToModel() {
        # PowerShellでの親クラスメソッド呼び出しはキャストを使用します
        return ([XmlJsonBase]$this).ToModel()
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

    # --- 静的メソッド ---

    static [hashtable[]] NormalizeData($input) {
        # 位置指定（lat/lonがあるハッシュテーブル）なら住所解決して1件のリストにする
        if ($input -is [hashtable] -and $input.lat -and $input.lon) {
            $pt = [GeoService]::ResolveAddress($input)
            return @($pt)
        }

        # キーワード抽出 (PowerShell 7.0+ の三項演算子、または if で対応)
        $keyword = if ($input -is [hashtable]) { $input.keyword } else { $input }

        # キーワード検索 → trkpt 候補を返す
        return [GeoService]::SearchPlace($keyword)
    }

    static [GPXService] Search($input) {
        $gpx = [GPXService]::new()

        # 1. keyword を metadata に保存
        if ($input -is [string]) {
            $gpx.Model.metadata.keywords = $input
        }
        elseif ($input -is [hashtable] -and $input.keyword) {
            $gpx.Model.metadata.keywords = $input.keyword
        }

        # 2. NormalizeData
        $pts = [GPXService]::NormalizeData($input)
        switch ($pts.Count) {
            0 { }
            1 {
                $pt = $pts[0]
                $gpx.Model.metadata.name = $pt.name
                $gpx.Model.metadata.desc = $pt.desc
                $gpx.Model.metadata.extensions = $pt.extensions
                $gpx.SetTrkpts(@($pt))
            }
            default {
                # 候補が複数ある場合は Waypoints としてセット
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
        elseif ($input -is [hashtable] -and $input.keyword) {
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

                # 自治体内の町字を取得してトラックポイントに設定
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
        elseif ($input -is [hashtable] -and $input.keyword) {
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

                # 半径指定などのエリア検索
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

# --- クラス定義後の静的初期化 ---
[GPXService]::xsd = Join-Path $script:ModuleRoot "config\gpx.xsd"


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
