using module D:\tool\Repository\PSTools\RouteOptimizer

# ============================
# ConvertValue (static)
# ============================
function ConvertValue([string]$value, [string]$xsdType) {
    switch ($xsdType) {
        "decimal" { return [double]$value }
        "int" { return [int]$value }
        "integer" { return [int]$value }
        "boolean" { return [bool]$value }
        "dateTime" { return [datetime]$value }
        default { return $value }
    }
    return $null
}

# ============================
# ElementToPSO (static)
# ============================
function ElementToPSO([System.Xml.XmlElement]$elem) {

    if (-not $elem) { return $null }
    $pso = @{}

    # --- 属性 ---
    foreach ($attr in $elem.Attributes) {
        if ($attr.Name -eq "xmlns" -or $attr.Prefix -eq "xmlns") { continue }
        $xsdType = [GPXDocument]::TypeMap[$attr.Name]
        $pso[$attr.Name] = ConvertValue $attr.Value $xsdType
    }

    # --- 子ノードを LocalName でグループ化 ---
    $groups = $elem.ChildNodes |
    Where-Object { $_.NodeType -ne [System.Xml.XmlNodeType]::Text } |
    Group-Object LocalName

    foreach ($group in $groups) {
        $name = $group.Name
        $xsdType = [GPXDocument]::TypeMap[$name]

        # ✅ @() で配列化を強制 → Text が char[] にならない
        $items = @(
            foreach ($child in $group.Group) {
                if ($child.HasChildNodes -and $child.ChildNodes.Count -gt 1) {
                    ElementToPSO $child
                }
                else {
                    ConvertValue $child.InnerText $xsdType
                }
            }
        )

        # ✅ 単数なら値、複数なら配列
        $pso[$name] = if ($items.Count -eq 1) { $items[0] } else { $items }
    }

    return $pso
}

$gpx = [GPXDocumentFactory]::FromCityTowns("葉山町", $true)

ElementToPSO($gpx.gpx) | ConvertTo-Json -Depth 10 

