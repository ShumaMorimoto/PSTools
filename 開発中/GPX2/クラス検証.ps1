

class GPXDocument : System.Xml.XmlDocument {

    hidden static [string] $GpxNamespace = "http://www.topografix.com/GPX/1/1"
    static [hashtable] $TypeMap = @{}

    static GPXDocument() {
        [GPXDocument]::LoadSchema()
    }

    # ================================
    #  XSD → TypeMap
    # ================================
    static hidden [void] LoadSchema() {

        # 実行ファイルのディレクトリから gpx.xsd を探す
        $xsdPath = "D:\tool\Repository\PSTools\RouteOptimizer\config\gpx.xsd"

        if (-not (Test-Path $xsdPath)) {
            throw "XSD not found: $xsdPath"
        }

        $schemaSet = [System.Xml.Schema.XmlSchemaSet]::new()
        $schemaSet.Add([GPXDocument]::GpxNamespace, $xsdPath) | Out-Null
        $schemaSet.Compile()

        # simpleType の継承関係
        $simpleTypes = @{}

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

                    [GPXDocument]::TypeMap[$item.Name] = @{
                        BaseType    = $base
                        IsAttribute = $false
                    }
                }

                # complexType の属性
                if ($item -is [System.Xml.Schema.XmlSchemaComplexType]) {
                    foreach ($attr in $item.Attributes) {
                        $typeName = $attr.SchemaTypeName.Name
                        $base = $simpleTypes.ContainsKey($typeName) ? (ResolveBase $typeName) : $typeName

                        [GPXDocument]::TypeMap[$attr.Name] = @{
                            BaseType    = $base
                            IsAttribute = $true
                        }
                    }
                }
            }
        }
    }

    # ================================
    #  型変換（XML → PSO）
    # ================================
    hidden static [object] ConvertValue([string]$text, [string]$baseType) {

        if ($null -eq $text -or $text -eq "") { return $null }

        switch ($baseType) {
            "decimal" { return [double]$text }
            "int" { return [int]$text }
            "integer" { return [int]$text }
            "boolean" { return [bool]$text }
            "dateTime" { return [datetime]$text }
            default { return $text }
        }
        return $null
    }

    # ================================
    #  型変換（PSO → XML）
    # ================================
    hidden static [string] ConvertToString($value, [string]$baseType) {

        if ($null -eq $value) { return "" }

        switch ($baseType) {
            "decimal" { return $value.ToString("G") }
            "int" { return $value.ToString() }
            "integer" { return $value.ToString() }
            "boolean" { return $value.ToString().ToLower() }
            "dateTime" { return $value.ToString("o") }
            default { return [string]$value }
        }
        return $null
    }

    # ================================
    #  XML → PSO
    # ================================
    hidden [object] ElementToPSO([System.Xml.XmlElement]$elem) {

        if (-not $elem) { return $null }
        $pso = @{}

        # --- 属性 ---
        foreach ($attr in $elem.Attributes) {
            if ($attr.Name -eq "xmlns" -or $attr.Prefix -eq "xmlns") { continue }

            $typeInfo = [GPXDocument]::TypeMap[$attr.Name]
            $pso[$attr.Name] = [GPXDocument]::ConvertValue($attr.Value, $typeInfo.BaseType)
        }

        # --- 子ノードを LocalName でグループ化 ---
        $groups = $elem.ChildNodes |
        Where-Object { $_.NodeType -ne "Text" } |
        Group-Object LocalName

        foreach ($group in $groups) {
            $name = $group.Name
            $typeInfo = [GPXDocument]::TypeMap[$name]

            $items = @(
                foreach ($child in $group.Group) {
                    if ($child.HasChildNodes -and $child.ChildNodes.Count -gt 1) {
                        $this.ElementToPSO($child)
                    }
                    else {
                        [GPXDocument]::ConvertValue($child.InnerText, $typeInfo.BaseType)
                    }
                }
            )

            $pso[$name] = ($items.Count -eq 1) ? $items[0] : $items
        }

        return $pso
    }

    # ================================
    #  PSO → XML
    # ================================
    hidden [System.Xml.XmlElement] CreateElementFromPSO([string]$name, $pso) {

        $elem = $this.CreateElement($name, [GPXDocument]::GpxNamespace)
        if (-not $pso) { return $elem }

        $pairs = ($pso -is [hashtable]) ? $pso.GetEnumerator() : $pso.PSObject.Properties

        foreach ($pair in $pairs) {
            $key = $pair.Key
            $value = $pair.Value
            $typeInfo = [GPXDocument]::TypeMap[$key]

            if ($typeInfo.IsAttribute) {
                $attr = $this.CreateAttribute($key)
                $attr.Value = [GPXDocument]::ConvertToString($value, $typeInfo.BaseType)
                $elem.Attributes.Append($attr) | Out-Null
            }
            else {
                $items = ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) ? $value : @($value)

                foreach ($item in $items) {
                    if ($item -is [hashtable] -or $item -is [psobject]) {
                        $child = $this.CreateElementFromPSO($key, $item)
                        $elem.AppendChild($child) | Out-Null
                    }
                    else {
                        $child = $this.CreateElement($key, [GPXDocument]::GpxNamespace)
                        $child.InnerText = [GPXDocument]::ConvertToString($item, $typeInfo.BaseType)
                        $elem.AppendChild($child) | Out-Null
                    }
                }
            }
        }

        return $elem
    }
}

# --- テスト用 GPX サンプル ---
$xmlText = @"
<wpt lat="35.258634" lon="139.593622" xmlns="http://www.topografix.com/GPX/1/1">
  <name>下山口</name>
  <desc>下山口, 葉山町, 三浦郡, 神奈川県, 240-0111, 日本</desc>
  <extensions>
    <ISO3166-2-lvl4>JP-14</ISO3166-2-lvl4>
    <neighbourhood>下山口</neighbourhood>
    <country_code>jp</country_code>
  </extensions>
</wpt>
"@

# --- GPXDocument をロード ---
$doc = [GPXDocument]::new()
$doc.LoadXml($xmlText)

# --- XML → PSO ---
$pso = $doc.ElementToPSO($doc.DocumentElement)

"=== PSO ==="
$pso | ConvertTo-Json -Depth 10 | Write-Host

# --- PSO → XML ---
$roundtrip = $doc.CreateElementFromPSO("wpt", $pso)
$doc2 = [GPXDocument]::new()
$imported = $doc2.ImportNode($roundtrip, $true)
$doc2.AppendChild($imported) | Out-Null

"=== Roundtrip XML ==="
$doc2.OuterXml | Write-Host

# --- 差分チェック ---
"=== Diff (Original vs Roundtrip) ==="
if ($doc.OuterXml -eq $doc2.OuterXml) {
    "✅ 完全一致（双方向変換 OK）"
}
else {
    "❌ 不一致（差分あり）"
    "---- Original ----"
    $doc.OuterXml
    "---- Roundtrip ----"
    $doc2.OuterXml
}