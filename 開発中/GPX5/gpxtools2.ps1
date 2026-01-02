class GPXService {
    static $TypeMap = @{
        domain = @{ BaseType = 'string'; IsAttribute = $true }
        maxlat = @{ BaseType = 'decimal'; IsAttribute = $true }
        gpx = @{ BaseType = 'gpxType'; IsAttribute = $false }
        author = @{ BaseType = 'string'; IsAttribute = $true }
        minlon = @{ BaseType = 'decimal'; IsAttribute = $true }
        minlat = @{ BaseType = 'decimal'; IsAttribute = $true }
        id = @{ BaseType = 'string'; IsAttribute = $true }
        href = @{ BaseType = 'anyURI'; IsAttribute = $true }
        lon = @{ BaseType = 'decimal'; IsAttribute = $true }
        lat = @{ BaseType = 'decimal'; IsAttribute = $true }
        maxlon = @{ BaseType = 'decimal'; IsAttribute = $true }
        version = @{ BaseType = 'string'; IsAttribute = $true }
        creator = @{ BaseType = 'string'; IsAttribute = $true }
        trk = @{ BaseType = 'object'; IsAttribute = $false }
        trkseg = @{ BaseType = 'object'; IsAttribute = $false }
        trkpt = @{ BaseType = 'object'; IsAttribute = $false }
        extensions = @{ BaseType = 'object'; IsAttribute = $false }
        name = @{ BaseType = 'string'; IsAttribute = $false }
        desc = @{ BaseType = 'string'; IsAttribute = $false }
        muitiRoute = @{ BaseType = 'string'; IsAttribute = $true }
    }

    static $GpxNamespace = 'http://www.topografix.com/GPX/1/1'

    [xml]$doc
    [hashtable]$model

    GPXService([hashtable]$initialModel = $null) {
        $this.doc = New-Object System.Xml.XmlDocument
        $gpx = $this.doc.CreateElement('gpx', [GPXService]::GpxNamespace)
        $this.doc.AppendChild($gpx) | Out-Null
        $this.model = $this._normalizeModel($initialModel)
    }

    [void]setModel([hashtable]$model) {
        $this.model = $this._normalizeModel($model)
    }

    [hashtable]getModel() {
        return $this.model
    }

    [void]loadFromXml([string]$xmlString) {
        $json = [GPXService]::xmlToJson($xmlString)
        $this.setModel($json)
    }

    [string]toXml() {
        if (-not $this.model) { return '' }
        return [GPXService]::jsonToXml($this.model, $this.doc)
    }

    static [string]jsonToXml([hashtable]$json, [xml]$doc) {
        $root = [GPXService]::createElementFromObject('gpx', $json, $doc)
        $root.SetAttribute('version', '1.1')
        $root.SetAttribute('xmlns', [GPXService]::GpxNamespace)
        $doc.ReplaceChild($root, $doc.DocumentElement) | Out-Null
        $xmlString = $doc.OuterXml
        return '<?xml version="1.0" encoding="UTF-8"?>' + $xmlString
    }

    static [System.Xml.XmlElement]createElementFromObject([string]$name, [hashtable]$obj, [xml]$doc) {
        $elem = $doc.CreateElement($name, [GPXService]::GpxNamespace)
        if (-not $obj) { return $elem }

        foreach ($kv in $obj.GetEnumerator()) {
            $key = $kv.Key
            $value = $kv.Value
            if ($key.StartsWith('_')) { continue }

            $outputKey = $key
            $typeInfo = [GPXService]::TypeMap[$outputKey]
            if (-not $typeInfo) { $typeInfo = @{ BaseType = 'string'; IsAttribute = $false } }

            if ($typeInfo.IsAttribute) {
                $elem.SetAttribute($outputKey, [GPXService]::convertToString($value, $typeInfo.BaseType))
            } else {
                $items = if ($value -is [array]) { $value } else { @($value) }
                foreach ($item in $items) {
                    if ($item -is [hashtable]) {
                        $child = [GPXService]::createElementFromObject($outputKey, $item, $doc)
                        $elem.AppendChild($child) | Out-Null
                    } else {
                        $child = $doc.CreateElement($outputKey, [GPXService]::GpxNamespace)
                        $child.InnerText = [GPXService]::convertToString($item, $typeInfo.BaseType)
                        $elem.AppendChild($child) | Out-Null
                    }
                }
            }
        }

        return $elem
    }

    static [string]convertToString($value, [string]$baseType) {
        if ($null -eq $value) { return '' }

        switch ($baseType) {
            'decimal' { return $value.ToString() }
            'int' { return [math]::Floor($value).ToString() }
            'integer' { return [math]::Floor($value).ToString() }
            'boolean' { return $value.ToString().ToLower() }
            'dateTime' { return (Get-Date $value).ToString('o') }
            default { return [string]$value }
        }
        return $null
    }

    static [hashtable]xmlToJson([string]$xmlString) {
        return [GPXService]::elementToObject(([xml]$xmlString).DocumentElement)
    }

    static [hashtable]elementToObject([System.Xml.XmlElement]$elem) {
        if (-not $elem) { return $null }
        $obj = @{}

        # Attributes
        foreach ($attr in $elem.Attributes) {
            if ($attr.Name -eq 'xmlns' -or $attr.Prefix -eq 'xmlns') { continue }
            $typeInfo = [GPXService]::TypeMap[$attr.Name]
            if (-not $typeInfo) { $typeInfo = @{ BaseType = 'string' } }
            $obj[$attr.Name] = [GPXService]::convertValue($attr.Value, $typeInfo.BaseType)
        }

        # Child nodes
        $groups = @{}
        foreach ($child in $elem.ChildNodes) {
            if ($child.NodeType -eq 'Text') { continue }
            if ($child.LocalName.StartsWith('_')) { continue }
            if (-not $groups.ContainsKey($child.LocalName)) { $groups[$child.LocalName] = @() }
            $groups[$child.LocalName] += $child
        }

        foreach ($kv in $groups.GetEnumerator()) {
            $name = $kv.Key
            $group = $kv.Value
            $modelName = $name
            $typeInfo = [GPXService]::TypeMap[$modelName]
            if (-not $typeInfo) { $typeInfo = @{ BaseType = 'string' } }
            $items = @()
            foreach ($child in $group) {
                if ($child.HasAttributes -or $child.HasChildNodes) {
                    $items += [GPXService]::elementToObject($child)
                } else {
                    $items += [GPXService]::convertValue($child.InnerText.Trim(), $typeInfo.BaseType)
                }
            }
            $obj[$modelName] = if ($items.Count -eq 1) { $items[0] } else { $items }
        }
        return $obj
    }

    static [object]convertValue([string]$text, [string]$baseType) {
        if ($null -eq $text -or $text -eq '') { return $null }

        switch ($baseType) {
            'decimal' { return [double]$text }
            'int' { return [int]$text }
            'integer' { return [int]$text }
            'boolean' { return $text.ToLower() -eq 'true' }
            'dateTime' { return Get-Date $text }
            default { return $text }
        }
        return $null
    }

    [array]getTrkpts() {
        return $this.model.trk.trkseg.trkpt
    }

    [void]setTrkpts([array]$pts) {
        $trkseg = $this._ensureTrkseg()
        $trkseg.trkpt = if ($pts -is [array]) { $pts.Clone() } else { @() }
    }

    [hashtable]appendTrkpt([hashtable]$trkptObj = @{}) {
        if (-not $trkptObj.ContainsKey('lat') -or -not $trkptObj.ContainsKey('lon')) {
            throw 'lat and lon are required for trkpt'
        }
        $trkpt = $trkptObj.Clone()
        $trkseg = $this._ensureTrkseg()
        if (-not $trkseg.ContainsKey('trkpt')) { $trkseg.trkpt = @() }
        $trkseg.trkpt += $trkpt
        return $trkpt
    }

    [void]removeTrkpt([hashtable]$point) {
        $pts = $this.getTrkpts()
        $idx = [array]::IndexOf($pts, $point)
        if ($idx -ge 0) {
            $newPts = $pts[0..($idx-1)] + $pts[($idx+1)..($pts.Length-1)]
            $this.setTrkpts($newPts)
        }
    }

    hidden [hashtable]_normalizeModel([hashtable]$model) {
        if (-not $model) {
            return @{
                version = '1.1'
                creator = 'MapSelector'
                trk = @{ trkseg = @{ trkpt = @() } }
            }
        }

        if (-not $model.ContainsKey('trk')) { $model.trk = @{} }
        if (-not $model.trk.ContainsKey('trkseg')) { $model.trk.trkseg = @{} }
        $model.trk.trkseg.trkpt = if ($model.trk.trkseg.trkpt -is [array]) { $model.trk.trkseg.trkpt } else { if ($model.trk.trkseg.trkpt) { @($model.trk.trkseg.trkpt) } else { @() } }

        return $model
    }

    hidden [hashtable]_ensureTrkseg() {
        if (-not $this.model.ContainsKey('trk')) { $this.model.trk = @{} }
        if (-not $this.model.trk.ContainsKey('trkseg')) { $this.model.trk.trkseg = @{} }
        return $this.model.trk.trkseg
    }
}