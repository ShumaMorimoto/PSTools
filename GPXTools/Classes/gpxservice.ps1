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

Write-Host "=== 7. Full Round-Trip Test (XML -> JSON -> Model -> XML) ===" -ForegroundColor Cyan

# 1. 初期データ作成（複雑な構造）
$originalSvc = [GPXService]::new()
$originalSvc.AddTrkpt(@{
    lat = 35.86297
    lon = 136.253159
    muitiRoute = "1"
    name = "文室町"
    extensions = @{
        road = "文堂池泉線"
        city = "越前市"
    }
})

# 2. 最初のXMLを生成
$firstXml = $originalSvc.ToXml()
Write-Host "[Step 1] First XML generated."

# 3. JSON化して出力 (Hashtable -> JSON String)
$json = $originalSvc.Model | ConvertTo-Json -Depth 10
Write-Host "[Step 2] Model serialized to JSON string."

# 4. 新しいサービスインスタンスでJSONから復元
$recoveredSvc = [GPXService]::new()
# JSON文字列をハッシュテーブルに戻してセット
$recoveredSvc.Model = $json | ConvertFrom-Json -AsHashtable
Write-Host "[Step 3] JSON deserialized back to New Model."

# 5. 二度目のXMLを生成
$secondXml = $recoveredSvc.ToXml()
Write-Host "[Step 4] Second XML generated from recovered model."

Write-Host "`n=== Verification Results ===" -ForegroundColor Yellow

# 検証 A: 文字列一致
if ($firstXml -eq $secondXml) {
    Write-Host "[SUCCESS] XML strings are identical!" -ForegroundColor Green
} else {
    Write-Host "[WARNING] XML strings differ. Checking details..." -ForegroundColor Yellow
    
    # 検証 B: 重要な属性が維持されているか
    if ($secondXml -match 'lat="35.86297"' -and $secondXml -match 'muitiRoute="1"') {
        Write-Host "[OK] Critical attributes (lat, muitiRoute) are preserved." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Critical attributes lost!" -ForegroundColor Red
    }
    
    # 検証 C: 構造の維持
    $recoveredPt = $recoveredSvc.GetTrkpts()[0]
    if ($recoveredPt.extensions.road -eq "文堂池泉線") {
        Write-Host "[OK] Deep structure (extensions) preserved." -ForegroundColor Green
    }
}

# ファイルに保存して比較しやすくする
$firstXml | Out-File "roundtrip_1.xml" -Encoding utf8
$secondXml | Out-File "roundtrip_2.xml" -Encoding utf8
Write-Host "`nSaved: roundtrip_1.xml and roundtrip_2.xml for manual diff."