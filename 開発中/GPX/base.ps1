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