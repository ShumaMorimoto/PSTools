using namespace System.Xml 
using namespace System.Xml.Schema 
using namespace System.Collections 
using namespace System.Collections.Generic

class XmlToHashtableBase {

    # メンバ変数
    [XmlSchemaSet] hidden $_schemaSet
    [XmlReaderSettings] hidden $_readerSettings

    # 外部公開する検証エラーリスト
    [System.Collections.ArrayList] $ValidationErrors

    # ---------------------------------------------------------
    # コンストラクタ 1: ファイルパスから生成 (通常用)
    # ---------------------------------------------------------
    XmlToHashtableBase([string[]]$xsdPaths) {
        $this.ValidationErrors = [System.Collections.ArrayList]::new()
    
        # スキーマセットの構築
        $set = New-Object System.Xml.Schema.XmlSchemaSet
        foreach ($path in $xsdPaths) {
            if (Test-Path $path) { $set.Add($null, $path) | Out-Null }
        }
        $set.Compile()
    
        $this._InitSettings($set)
    }

    # ---------------------------------------------------------
    # コンストラクタ 2: 既存のスキーマセットから生成 (高速化用)
    # ---------------------------------------------------------
    XmlToHashtableBase([XmlSchemaSet]$compiledSet) {
        $this.ValidationErrors = [System.Collections.ArrayList]::new()
        $this._InitSettings($compiledSet)
    }

    # 共通初期化処理
    hidden [void] _InitSettings([XmlSchemaSet]$set) {
        $this._schemaSet = $set
        $this._readerSettings = New-Object System.Xml.XmlReaderSettings
        $this._readerSettings.Schemas = $this._schemaSet
        $this._readerSettings.ValidationType = [System.Xml.ValidationType]::Schema
    
        # エラーハンドラ
        $errors = $this.ValidationErrors
        $this._readerSettings.add_ValidationEventHandler({ param($s, $e) 
                if ($e.Severity -eq "Error") { 
                    $errors.Add("Line $($e.Exception.LineNumber): $($e.Message)") | Out-Null 
                }
            })
    }

    # ---------------------------------------------------------
    # Public メソッド: ファイル解析
    # ---------------------------------------------------------
    [System.Collections.IDictionary] ParseFile([string]$xmlFilePath) {
        if (-not (Test-Path $xmlFilePath)) { throw "XML File not found: $xmlFilePath" }
        $reader = [XmlReader]::Create($xmlFilePath, $this._readerSettings)
        try { return $this._LoadAndConvert($reader) } finally { $reader.Close() }
    }

    # ---------------------------------------------------------
    # 内部ロジック (前回のコードと同じため、主要部分のみ記載)
    # ---------------------------------------------------------
    hidden [System.Collections.IDictionary] _LoadAndConvert([XmlReader]$reader) {
        $this.ValidationErrors.Clear()
        $doc = New-Object System.Xml.XmlDocument
        $doc.Load($reader)
        $doc.Validate($null)
        if ($this.ValidationErrors.Count -gt 0) { Write-Warning "XML Validation Errors Found" }
        return $this._ConvertNode($doc.DocumentElement)
    }

    hidden [object] _ConvertNode([XmlNode]$node) {
        if ($node.NodeType -eq [XmlNodeType]::Text -or $node.NodeType -eq [XmlNodeType]::CDATA) {
            return $this._CastValue($node)
        }
        $result = [ordered]@{}
        if ($node.Attributes) {
            foreach ($attr in $node.Attributes) {
                if ($attr.Name -match "^xmlns") { continue }
                $result[$attr.Name] = $this._CastValue($attr)
            }
        }
        if ($node.HasChildNodes) {
            if ($node.ChildNodes.Count -eq 1 -and ($node.FirstChild.NodeType -eq [XmlNodeType]::Text -or $node.FirstChild.NodeType -eq [XmlNodeType]::CDATA)) {
                $textVal = $this._CastValue($node.FirstChild)
                if ($result.Count -gt 0) { $result["#text"] = $textVal } else { return $textVal }
            }
            else {
                $groupedChildren = $node.ChildNodes | Where-Object { $_.NodeType -eq [XmlNodeType]::Element } | Group-Object { "$($_.NamespaceURI)|$($_.LocalName)" }
                foreach ($group in $groupedChildren) {
                    $sampleNode = $group.Group[0]
                    $childName = $sampleNode.LocalName
                    $isArray = $this._IsArrayDefinition($node, $sampleNode)
                    if ($isArray -or $group.Count -gt 1) {
                        $list = [System.Collections.ArrayList]::new()
                        foreach ($child in $group.Group) { $list.Add($this._ConvertNode($child)) | Out-Null }
                        $result[$childName] = $list
                    }
                    else {
                        $result[$childName] = $this._ConvertNode($sampleNode)
                    }
                }
            }
        }
        return $result
    }

    hidden [object] _CastValue([XmlNode]$node) {
        $val = $node.Value
        $schemaInfo = $node.SchemaInfo
        if ($null -eq $schemaInfo -or $null -eq $schemaInfo.SchemaType) { return $val }
        switch ($schemaInfo.SchemaType.TypeCode) {
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

    # 配列かどうかの判定ロジック
    hidden [bool] _IsArrayDefinition([XmlNode]$parentNode, [XmlNode]$childNode) {
        $pSchema = $parentNode.SchemaInfo
        if ($null -eq $pSchema -or $null -eq $pSchema.SchemaType) { return $false }
        if ($pSchema.SchemaType -isnot [XmlSchemaComplexType]) { return $false }
    
        $contentType = $pSchema.SchemaType.ContentTypeParticle
        return $this._FindParticleMaxOccurs($contentType, $childNode.LocalName, $childNode.NamespaceURI)
    }

    hidden [bool] _FindParticleMaxOccurs($particle, [string]$name, [string]$ns) {
        if ($null -eq $particle) { return $false }

        if ($particle -is [XmlSchemaElement]) {
            if ($particle.Name -eq $name -and $particle.QualifiedName.Namespace -eq $ns) {
                return ($particle.MaxOccursString -eq "unbounded" -or $particle.MaxOccurs > 1)
            }
        }

        if ($particle -is [XmlSchemaGroupBase]) {
            $groupIsArray = ($particle.MaxOccursString -eq "unbounded" -or $particle.MaxOccurs > 1)
            foreach ($item in $particle.Items) {
                if ($this._FindParticleMaxOccurs($item, $name, $ns)) { return $true }
            
                # グループ自体が配列で、その中の要素にマッチした場合もTrue
                if ($groupIsArray) {
                    if ($item -is [XmlSchemaElement] -and 
                        $item.Name -eq $name -and 
                        $item.QualifiedName.Namespace -eq $ns) {
                        return $true
                    }
                }
            }
        }
        return $false
    }
}

class GpxService : XmlToHashtableBase {
    
    # ---------------------------------------------------------
    # 静的メンバ: スキーマセットをキャッシュする
    # ---------------------------------------------------------
    static [XmlSchemaSet] $_cachedSchemaSet
    
    # Staticコンストラクタ: クラス初回ロード時に1回だけ走る
    static GpxService() {
        # ここでXSDのパスを指定します（実運用では環境変数や設定ファイルから取得推奨）
        # 例としてTEMPフォルダの schema.xsd を指定
        $xsdPath = Join-Path $env:TEMP "schema.xsd"
        
        if (-not (Test-Path $xsdPath)) {
            Write-Warning "GPX Schema not found at $xsdPath"
            return
        }

        # スキーマセットを作成・コンパイル
        [GpxService]::_cachedSchemaSet = New-Object System.Xml.Schema.XmlSchemaSet
        [GpxService]::_cachedSchemaSet.Add($null, $xsdPath) | Out-Null
        [GpxService]::_cachedSchemaSet.Compile()
    }

    # ---------------------------------------------------------
    # インスタンスプロパティ: 変換後のデータを保持
    # ---------------------------------------------------------
    [System.Collections.IDictionary] $Data

    # コンストラクタ (外部からは From メソッドを使うので隠蔽気味でも良い)
    GpxService() : base([GpxService]::$_cachedSchemaSet) {
    }

    # ---------------------------------------------------------
    # ファクトリメソッド (Static)
    # ---------------------------------------------------------
    static [GpxService] From([string]$xmlPath) {
        if ($null -eq [GpxService]::_cachedSchemaSet) {
            throw "GPX Schema is not loaded properly."
        }

        # インスタンス生成
        $instance = [GpxService]::new()
        
        # パース実行してプロパティに格納
        # (親クラスの ParseFile を利用)
        $instance.Data = $instance.ParseFile($xmlPath)

        return $instance
    }
    
    # ---------------------------------------------------------
    # ユーティリティメソッド (必要に応じて追加)
    # ---------------------------------------------------------
    
    # 例: バリデーションエラーがあるか確認
    [bool] IsValid() {
        return $this.ValidationErrors.Count -eq 0
    }
}

# ==========================================
# テストデータの準備 (XSD と XML)
# ==========================================
$xsdContent = @"
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://example.com/geo" xmlns="http://example.com/geo" elementFormDefault="qualified">
    <xs:element name="gpx">
        <xs:complexType>
            <xs:sequence>
                <xs:element name="trkpt" minOccurs="0" maxOccurs="unbounded">
                    <xs:complexType>
                        <xs:attribute name="lat" type="xs:decimal" use="required" />
                        <xs:attribute name="lon" type="xs:decimal" use="required" />
                    </xs:complexType>
                </xs:element>
            </xs:sequence>
            <xs:attribute name="creator" type="xs:string" />
        </xs:complexType>
    </xs:element>
</xs:schema>
"@
$xsdPath = Join-Path $env:TEMP "schema.xsd"
$xsdContent | Set-Content -Path $xsdPath -Encoding UTF8

$xmlContent = @"
<gpx xmlns="http://example.com/geo" creator="MyGPS">
    <trkpt lat="35.6895" lon="139.6917" />
    <trkpt lat="34.6937" lon="135.5023" />
</gpx>
"@
$xmlPath = Join-Path $env:TEMP "data.xml"
$xmlContent | Set-Content -Path $xmlPath -Encoding UTF8


# ==========================================
# GpxService の利用
# ==========================================

try {
    # 1. 静的メソッドでロード＆パース (ここでXSDも初回のみロードされる)
    $gpx = [GpxService]::From($xmlPath)

    # 2. エラーチェック
    if (-not $gpx.IsValid()) {
        Write-Error "Validation failed:"
        $gpx.ValidationErrors | ForEach-Object { Write-Error $_ }
    }
    else {
        # 3. データの利用
        Write-Host "Creator: $($gpx.Data.creator)"
        
        # trkptはXSDでunboundedなので、常にArrayListとして扱える
        foreach ($pt in $gpx.Data.trkpt) {
            # 数値型(decimal)として計算可能
            $lat = $pt.lat
            Write-Host "Lat: $lat (Type: $($lat.GetType().Name))"
        }
        
        # JSON化して確認
        # $gpx.Data | ConvertTo-Json -Depth 5
    }

}
catch {
    Write-Error $_
}
