class GPXDocument : System.Xml.XmlDocument {
    hidden static $creator = "GPXDocument クラス"
    hidden static [string] $GpxNamespace = "http://www.topografix.com/GPX/1/1"
    hidden static [System.Xml.XmlNamespaceManager] $NamespaceManager
    hidden static [string] $xsdPath = (Join-Path $script:ModuleRoot "config/gpx.xsd")
    static [hashtable] $TypeMap = @{}

    # 初期化: 名前空間マネージャを設定
    static [void] Initialize([System.Xml.XmlDocument]$doc) {
        if (-not [GPXDocument]::NamespaceManager -and $doc.DocumentElement) {
            [GPXDocument]::NamespaceManager = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
            [GPXDocument]::NamespaceManager.AddNamespace("gpx", $doc.DocumentElement.NamespaceURI)
        }
    }
    # --- XSD を読み込んで TypeMap を構築 ---
    static hidden [void] LoadSchema() {
        $schemaSet = [System.Xml.Schema.XmlSchemaSet]::new()
        $schemaSet.Add([GPXDocument]::GpxNamespace, [GPXDocument]::xsdPath) | Out-Null
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
    
    static GPXDocument() {
        [GPXDocument]::LoadSchema()
    }
    GPXDocument() { 
    }

    GPXDocument($rep) {
        # rep が文字列なら name にラップ、nullなら空ハッシュに
        if ($rep -is [string]) {
            $rep = @{ name = $rep } 
        }
        elseif (-not $rep) {
            $rep = @{} 
        }

        $this.AppendChild($this.CreateXmlDeclaration("1.0", "UTF-8", $null))

        # metadata 用 info を事前加工
        $metaInfo = [pscustomobject]@{
            time       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            name       = $rep.name
            desc       = $rep.desc
            extensions = $rep.address
        }
        # gpx のルート info
        $rootInfo = [pscustomobject]@{
            version  = "1.1"
            creator  = [GPXDocument]::creator
            metadata = $metaInfo
            trk      = @{ trkseg = $null }  # 空タグを info 展開で生成
        }

        $gpxRoot = $this.CreateElementFromPSO("gpx", $rootInfo)
        $gpxRoot.SetAttribute("xmlns", [GPXDocument]::GpxNamespace)
        $this.AppendChild($gpxRoot)

        [GPXDocument]::Initialize($this)
    }

    static [GPXDocument] LoadKmlFile([string]$path) {
        if (-not (Test-Path $path)) {
            throw "KMLファイルが見つかりません: $path"
        }
        $xml = [xml](Get-Content $path -Raw)
        return [GPXDocument]::FromKmlXml($xml)
    }
    static [GPXDocument] FromKmlXml([System.Xml.XmlDocument]$xmlDoc) {
        $placemarks = $xmlDoc.SelectNodes("//Placemark")
        $gpx = [GPXDocument]::new(@{
                name = "Converted from KML"
                desc = "KML source document"
            })

        foreach ($pm in $placemarks) {
            $name = $pm.SelectSingleNode("name")?.InnerText
            $coordText = $pm.SelectSingleNode("Point/coordinates")?.InnerText
            if (-not $coordText) { continue }

            $parts = $coordText.Trim() -split ","
            $lon = [double]$parts[0]
            $lat = [double]$parts[1]

            $gpx.AppendTrkPt(@{
                    lat  = $lat
                    lon  = $lon
                    name = $name
                    desc = $pm.SelectSingleNode("description")?.InnerText
                })
        }
        $gpx.UpdateStats()
        return $gpx
    }

    static [GPXDocument] Load([string]$path) {
        $doc = [GPXDocument]::new()
        $doc.Load($path)
        $root = $doc.DocumentElement
        if (-not $root.HasAttribute("version")) { $root.SetAttribute("version", "1.1") }
        if (-not $root.HasAttribute("xmlns")) { $root.SetAttribute("xmlns", [GPXDocument]::GpxNamespace) }
        [GPXDocument]::Initialize($doc)

        return $doc
    }
    static [GPXDocument] LoadXml([string]$xml) {
        $doc = [GPXDocument]::new()
        $doc.LoadXml($xml)
        [GPXDocument]::Initialize($doc)

        return $doc
    }

    [System.Xml.XmlElement[]] GetTrkPts() {
        return @($this.SelectNodes("//gpx:trk/gpx:trkseg/gpx:trkpt", [GPXDocument]::NamespaceManager))
    }

    [void] AppendTrkPt($info) {
        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NamespaceManager)
        if (-not $trkseg) { return }
        if ($info -is [System.Xml.XmlElement] -and $info.LocalName -eq "trkpt") {
            $trkseg.AppendChild($this.ImportNode($info, $true)) | Out-Null
        }
        else {
            # info を組み立てて PSO展開
            $info = [pscustomobject]@{
                lat        = $info.lat
                lon        = $info.lon
                name       = $info.name
                desc       = $info.desc
                extensions = $info.address
            }
            $trkpt = $this.CreateElementFromPSO("trkpt", $info)
            if ($trkpt) { $trkseg.AppendChild($trkpt) | Out-Null }
        }
    }

    [void] SetTrkPts([System.Xml.XmlElement[]]$pts) {
        $trkseg = $this.SelectSingleNode("//gpx:trk/gpx:trkseg", [GPXDocument]::NamespaceManager)
        $trkseg.RemoveAll()
        foreach ($pt in $pts) {
            $trkseg.AppendChild($this.ImportNode($pt, $true))
        }
    }

    [string] ToXmlString() { return $this.OuterXml }

    # ------- 統計情報などメソッド -------
    [hashtable] GetStats() {
        $trackPoints = $this.GetTrkPts()
        if (-not $trackPoints -or $trackPoints.Count -lt 2) {
            return @{ TotalDistanceKm = 0; PointCount = $trackPoints.Count }
        }
        $totalDistance = 0.0
        for ($i = 0; $i -lt $trackPoints.Count - 1; $i++) {
            $totalDistance += Get-Distance $trackPoints[$i] $trackPoints[$i + 1]
        }
        return @{
            TotalDistanceKm = [math]::Round($totalDistance, 2)
            PointCount      = $trackPoints.Count
        }
    }

    [void] UpdateStats() {
        $stats = $this.GetStats()
        if (-not $stats) { return }

        $trackNode = $this.SelectSingleNode("//gpx:trk", [GPXDocument]::NamespaceManager)
        if (-not $trackNode) { return }

        $extensionsNode = $trackNode.SelectSingleNode("gpx:extensions", [GPXDocument]::NamespaceManager)
        if (-not $extensionsNode) {
            # CreateElementFromPSOでextensionsノードを生成
            $extensionsNode = $this.CreateElementFromPSO("extensions")
            $trackNode.AppendChild($extensionsNode) | Out-Null
        }
        else {
            $existingStatsNode = $extensionsNode.SelectSingleNode("gpx:stats", [GPXDocument]::NamespaceManager)
            if ($existingStatsNode) { $extensionsNode.RemoveChild($existingStatsNode) | Out-Null }
        }

        # statsノードをPSO展開で生成
        $statsInfo = [pscustomobject]@{
            totalDistanceKm = ("{0:F2}" -f $stats.TotalDistanceKm)
            pointCount      = "$($stats.PointCount)"
        }

        $statsNode = $this.CreateElementFromPSO("stats", $statsInfo)
        $extensionsNode.AppendChild($statsNode) | Out-Null
    }

    [void] SetTrkName([string]$trackName) {
        $trackNode = $this.SelectSingleNode("//gpx:trk", [GPXDocument]::NamespaceManager)
        if (-not $trackNode) { return }
        $nameNode = $trackNode.SelectSingleNode("gpx:name", [GPXDocument]::NamespaceManager)
        if (-not $nameNode) {
            $nameNode = $this.CreateElement("name", $this.DocumentElement.NamespaceURI)
            $trackNode.AppendChild($nameNode) | Out-Null
        }
        $nameNode.InnerText = $trackName
    }

    static [string] GetTownName([System.Xml.XmlElement]$trkpt) {
        return [GPXDocument]::GetTownName($trkpt, 1)
    }
    static [string] GetTownName([System.Xml.XmlElement]$trkpt, [int]$level = 1) {
        if (-not $trkpt.extensions) { return "Unknown" }

        # 値を文字列化（XmlElement対応）
        function Get-Text($x) {
            if ($x -is [System.Xml.XmlElement]) { return $x.InnerText }
            else { return $x }
        }

        $province = Get-Text $trkpt.extensions.province
        $county = Get-Text $trkpt.extensions.county
        $city = Get-Text $trkpt.extensions.city
        $town = Get-Text $trkpt.extensionstown
        $village = Get-Text $trkpt.extensions.village
        $suburb = Get-Text $trkpt.extensions.suburb
        $quarter = Get-Text $trkpt.extensions.quarter
        $neigh = Get-Text $trkpt.extensions.neighbourhood

        switch ($level) {
            0 { return ($province + $county + $city + $town + $village + $suburb + $quarter + $neigh) }
            1 { return ($county + $city + $town + $village) }
            2 {
                if ($suburb) { return $suburb }
                elseif ($county -or $town -or $village) { return ($county + $town + $village) }
                elseif ($city) { return $city }
                else { return "Unknown" }
            }
            3 { return ($county + $city + $town + $village + $suburb + $quarter + $neigh) }
            default { return "Unknown" }
        }
        return "Unknown"
    }


    # ------- 以下エレメント生成ヘルパ -------
    hidden [System.Xml.XmlElement] CreateElementFromPSO([string]$tagName) {
        return $this.CreateElementFromPSO($tagName, $null)
    }
    # ================================
    #  PSO → XML
    # ================================
    hidden [System.Xml.XmlElement] CreateElementFromPSO([string]$name, [PSCustomObject]$pso) {
        $elem = $this.CreateElement($name, [GPXDocument]::GpxNamespace)
        if (-not $pso) { return $elem }

        $pairs = ($pso -is [hashtable]) ? $pso.GetEnumerator() : $pso.PSObject.Properties

        foreach ($pair in $pairs) {
            $key = $pair.Name
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
    hidden static [object] ElementToPSO([System.Xml.XmlElement]$elem) {

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
                        [GPXDocument]::ElementToPSO($child)
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
}