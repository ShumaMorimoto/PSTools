using namespace System.Xml 
using namespace System.Xml.Schema 
using namespace System.Collections 
using namespace System.Collections.Generic

class XsdJsonConverter {
    [XmlSchemaSet] $SchemaSet

    # コンストラクタ: XSDパス配列を受け取る
    XsdJsonConverter([string[]]$xsdPaths) {
        $this.SchemaSet = New-Object System.Xml.Schema.XmlSchemaSet
        $settings = New-Object System.Xml.XmlReaderSettings
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore

        foreach ($path in $xsdPaths) {
            try {
                $this.SchemaSet.Add($null, $path) | Out-Null
            }
            catch {
                Write-Warning "XSD Load Error ($path): $_"
            }
        }
        $this.SchemaSet.Compile()
    }

    # メイン変換メソッド
    [object] Convert([string]$xmlPath) {
        $settings = New-Object System.Xml.XmlReaderSettings
        $settings.Schemas = $this.SchemaSet
        $settings.ValidationType = [System.Xml.ValidationType]::Schema
    
        # エラーハンドラ（検証エラー時）
        $settings.add_ValidationEventHandler({ param($s, $e) 
                if ($e.Severity -eq "Error") { Write-Warning "Validation Error: $($e.Message)" }
            })

        $reader = [System.Xml.XmlReader]::Create($xmlPath, $settings)
        $doc = New-Object System.Xml.XmlDocument
        try {
            $doc.Load($reader) # ここで検証と型情報の紐付け(PSVI)が行われる
            $doc.Validate($null) # 念のためDOMレベルでも検証確定
        }
        finally {
            $reader.Close()
        }

        return $this._ParseNode($doc.DocumentElement)
    }

    # ノード解析（再帰）
    [object] _ParseNode([XmlNode]$node) {
        # 1. テキストノードの場合（単純値）
        if ($node.NodeType -eq [XmlNodeType]::Text -or $node.NodeType -eq [XmlNodeType]::CDATA) {
            return $this._CastValue($node)
        }

        # 結果格納用ハッシュテーブル (順序保持)
        $obj = [ordered]@{}
        $hasComplexContent = $false

        # 2. 属性の処理 (単純プロパティとして追加)
        if ($node.Attributes) {
            foreach ($attr in $node.Attributes) {
                # xmlns 定義はJSONデータとしては不要な場合が多いが、必要なら残す
                if ($attr.Name -match "^xmlns") { continue }
            
                # 属性の型変換
                $obj[$attr.Name] = $this._CastValue($attr)
            }
        }

        # 3. 子要素の処理
        if ($node.HasChildNodes) {
            # テキストのみの子要素を持つ場合 (例: <name>John</name>)
            if ($node.ChildNodes.Count -eq 1 -and 
                ($node.FirstChild.NodeType -eq [XmlNodeType]::Text -or 
                $node.FirstChild.NodeType -eq [XmlNodeType]::CDATA)) {
            
                $textVal = $this._CastValue($node.FirstChild)
            
                # 属性を持っている場合 -> { "id": 1, "#text": "John" }
                if ($obj.Count -gt 0) {
                    $obj["#text"] = $textVal
                } 
                # 属性がない場合 -> "John" (値を直接返す)
                else {
                    return $textVal
                }
            }
            else {
                # 複合要素の場合
                $hasComplexContent = $true
            
                # 子要素を「ローカル名+名前空間」でグルーピング
                # (要素名が同じでも名前空間が違うと別物扱い)
                $groupedChildren = $node.ChildNodes | 
                Where-Object { $_.NodeType -eq [XmlNodeType]::Element } | 
                Group-Object { "$($_.NamespaceURI)|$($_.LocalName)" }

                foreach ($group in $groupedChildren) {
                    # グループ内の最初の要素を使って定義を調べる
                    $sampleNode = $group.Group[0]
                    $childName = $sampleNode.LocalName
                
                    # --- ここで XSD の定義を確認 (配列か？) ---
                    $isSchemaArray = $this._IsArrayDefinition($node, $sampleNode)

                    if ($isSchemaArray) {
                        # maxOccurs > 1 なら必ず配列にする
                        $list = [System.Collections.ArrayList]::new()
                        foreach ($child in $group.Group) {
                            $list.Add($this._ParseNode($child)) | Out-Null
                        }
                        $obj[$childName] = $list
                    }
                    else {
                        # maxOccurs = 1 なら単一オブジェクト
                        # (万が一データ上に複数あっても、最後のもので上書き or 配列化のフォールバック)
                        if ($group.Count -gt 1) {
                            # スキーマ違反だがデータ優先で配列化
                            $list = [System.Collections.ArrayList]::new()
                            foreach ($child in $group.Group) { $list.Add($this._ParseNode($child)) | Out-Null }
                            $obj[$childName] = $list
                        }
                        else {
                            $obj[$childName] = $this._ParseNode($group.Group[0])
                        }
                    }
                }
            }
        }

        return [PSCustomObject]$obj
    }

    # 値の型変換
    [object] _CastValue([XmlNode]$node) {
        $val = $node.Value
        # SchemaInfoは検証成功後に利用可能
        $schemaInfo = $node.SchemaInfo
    
        if ($null -eq $schemaInfo -or $null -eq $schemaInfo.SchemaType) { return $val }

        $typeCode = $schemaInfo.SchemaType.TypeCode

        # 必要に応じて型定義を追加
        switch ($typeCode) {
            'Boolean' { return [System.Xml.XmlConvert]::ToBoolean($val) }
            'Int16' { return [System.Xml.XmlConvert]::ToInt16($val) }
            'Int32' { return [System.Xml.XmlConvert]::ToInt32($val) }
            'Int64' { return [System.Xml.XmlConvert]::ToInt64($val) }
            'Double' { return [System.Xml.XmlConvert]::ToDouble($val) }
            'Decimal' { return [System.Xml.XmlConvert]::ToDecimal($val) }
            'DateTime' { return [System.Xml.XmlConvert]::ToDateTime($val, [System.Xml.XmlDateTimeSerializationMode]::Local) }
            Default { return $val }
        }
        return $null
    }

    # 親要素の定義を調べて、対象の子要素が maxOccurs > 1 かどうか判定する
    [bool] _IsArrayDefinition([XmlNode]$parentNode, [XmlNode]$childNode) {
        $pSchema = $parentNode.SchemaInfo
        if ($null -eq $pSchema -or $null -eq $pSchema.SchemaType) { return $false }

        # 親が複合型(ComplexType)でないと子は持てない
        if ($pSchema.SchemaType -isnot [XmlSchemaComplexType]) { return $false }
    
        $contentType = $pSchema.SchemaType.ContentTypeParticle
    
        # 名前空間とローカル名で検索
        return $this._FindParticleMaxOccurs($contentType, $childNode.LocalName, $childNode.NamespaceURI)
    }

    # パーティクル(Sequence, Choice, All)を再帰探索
    [bool] _FindParticleMaxOccurs($particle, [string]$name, [string]$ns) {
        if ($null -eq $particle) { return $false }

        # Element定義の場合
        if ($particle -is [XmlSchemaElement]) {
            # 名前と名前空間の一致を確認
            if ($particle.Name -eq $name -and $particle.QualifiedName.Namespace -eq $ns) {
                # maxOccurs > 1 または "unbounded" なら配列
                return ($particle.MaxOccursString -eq "unbounded" -or $particle.MaxOccurs > 1)
            }
            # 要素参照(ref)の場合、参照先の定義を確認する必要があるが
            # XmlSchemaSetでコンパイル済みならName等は解決されていることが多い
        }
      
        # グループ定義 (Sequence, Choice, All) の場合
        if ($particle -is [XmlSchemaGroupBase]) {
            # グループ自体の maxOccurs も考慮する必要がある
            # (例: <sequence maxOccurs="unbounded"><element name="A" .../></sequence> の場合、Aは配列になる)
            $groupIsArray = ($particle.MaxOccursString -eq "unbounded" -or $particle.MaxOccurs > 1)

            foreach ($item in $particle.Items) {
                # 再帰的に検索
                $foundIsArray = $this._FindParticleMaxOccurs($item, $name, $ns)
                
                # 見つかった場合
                # 「要素自体が配列」または「親グループが配列」なら配列扱いとする
                if ($foundIsArray -or ($groupIsArray -and $this._IsMatchParticle($item, $name, $ns))) {
                    return $true
                }
                
                # ただ見つかっただけ(MaxOccurs=1)だが、親グループが配列の場合も考慮
                if ($this._IsMatchParticle($item, $name, $ns) -and $groupIsArray) {
                    return $true
                }
            }
        }
        
        return $false
    }

    # パーティクルが対象の要素名と一致するか確認するヘルパー
    [bool] _IsMatchParticle($particle, [string]$name, [string]$ns) {
        if ($particle -is [XmlSchemaElement]) {
            return ($particle.Name -eq $name -and $particle.QualifiedName.Namespace -eq $ns)
        }
        return $false
    }
}

# =============================================================================
# 使用例 (Usage Example)
# =============================================================================

# テスト用にサンプルXSDとXMLを作成して動作確認します
# (実際の使用時はファイルパスを指定してください)

$xsdContent = @"
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://example.com/geo" xmlns="http://example.com/geo" elementFormDefault="qualified">
    <xs:element name="gpx">
        <xs:complexType>
            <xs:sequence>
                <xs:element name="metadata" minOccurs="0" maxOccurs="1">
                    <xs:complexType>
                        <xs:sequence>
                            <xs:element name="name" type="xs:string" />
                            <xs:element name="time" type="xs:dateTime" />
                        </xs:sequence>
                    </xs:complexType>
                </xs:element>
                <!-- maxOccurs="unbounded" なので、データが1件でも配列になるべき -->
                <xs:element name="trkpt" minOccurs="0" maxOccurs="unbounded">
                    <xs:complexType>
                        <xs:attribute name="lat" type="xs:decimal" use="required" />
                        <xs:attribute name="lon" type="xs:decimal" use="required" />
                        <xs:attribute name="ele" type="xs:decimal" />
                    </xs:complexType>
                </xs:element>
            </xs:sequence>
            <xs:attribute name="version" type="xs:string" />
            <xs:attribute name="creator" type="xs:string" />
        </xs:complexType>
    </xs:element>
</xs:schema>
"@

# トラックポイントが「1つだけ」のデータ (配列化されるかテスト)
$xmlContent = @"
<gpx xmlns="http://example.com/geo" version="1.1" creator="MyTool">
    <metadata>
        <name>Kyoto Trip</name>
        <time>2023-10-27T10:00:00</time>
    </metadata>
    <trkpt lat="35.000" lon="135.000" ele="50.5" />
</gpx>
"@

$xsdPath = Join-Path $env:TEMP "schema.xsd"
$xmlPath = Join-Path $env:TEMP "data.xml"

$xsdContent | Set-Content -Path $xsdPath -Encoding UTF8
$xmlContent | Set-Content -Path $xmlPath -Encoding UTF8

try {
    # コンバータの初期化
    $converter = [XsdJsonConverter]::new(@($xsdPath))
    
    # 変換実行
    $pso = $converter.Convert($xmlPath)
    
    # JSONへ変換して表示
    # -Depth を深めに指定しないと入れ子が省略されるので注意
    $json = $pso | ConvertTo-Json -Depth 10
    
    Write-Host "--- Converted JSON ---"
    Write-Host $json

    # 結果の検証
    Write-Host "`n--- Verification ---"
    Write-Host "Attributes flattened? (lat): $($pso.trkpt[0].lat) (Type: $($pso.trkpt[0].lat.GetType().Name))"
    Write-Host "Single item is array? : $($pso.trkpt -is [System.Collections.IEnumerable])"
    Write-Host "DateTime typed?       : $($pso.metadata.time.GetType().Name)"

}
catch {
    Write-Error $_
}
