function ElementToPSO([System.Xml.XmlElement]$elem) {

    if (-not $elem) { return $null }

    $pso = @{}

    # --- 属性（xmlns は除外） ---
    foreach ($attr in $elem.Attributes) {

        if ($attr.Name -eq "xmlns" -or $attr.Prefix -eq "xmlns") {
            continue
        }

        $pso[$attr.Name] = $attr.Value
    }

    # --- 子ノード ---
    foreach ($child in $elem.ChildNodes) {

        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Text) {
            continue
        }

        $name = $child.LocalName

        if ($child.HasChildNodes -and $child.ChildNodes.Count -gt 1) {
            $pso[$name] = ElementToPSO($child)
        }
        else {
            $pso[$name] = $child.InnerText
        }
    }

    return $pso
}

$gpx = [GPXDocument]::new()
$xml = @"
<trkpt lat="35.0" lon="135.0" xmlns="http://www.topografix.com/GPX/1/1">
  <name>京都</name>
  <desc>京都駅</desc>
  <extensions>
    <city>京都市</city>
    <road>烏丸通</road>
  </extensions>
</trkpt>
"@

$doc = New-Object System.Xml.XmlDocument
$doc.LoadXml($xml)
$orig = $doc.DocumentElement

# --- Element → PSO ---

$pso = ElementToPSO $orig

Write-Host "PSO:" -ForegroundColor Cyan
$pso | Format-List

# --- PSO → Element（CreateElementFromPSO） ---
$new = $gpx.CreateElementFromPSO("trkpt", $pso, @("lat","lon"))

Write-Host "`n再構築されたXML:" -ForegroundColor Cyan
$new.OuterXml
