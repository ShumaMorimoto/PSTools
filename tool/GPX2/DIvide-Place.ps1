function Get-MunicipalityMetaFromExtensions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Extensions
    )

    $province = $Extensions.province
    $city     = $Extensions.city
    $suburb   = $Extensions.suburb
    $county   = $Extensions.county
    $town     = $Extensions.town
    $village  = $Extensions.village

    $meta = @{}

    # 東京23区（cityが「〇〇区」）はsuburbを無視し、provinceも省略
    if ($city -and $city -match '区$') {
        $meta["city"] = $city
    }
    # 市 + 区（例：仙台市青葉区）
    elseif ($city -and $suburb) {
        $meta["province"] = $province
        $meta["city"]     = $city
        $meta["suburb"]   = $suburb
    }
    # 市のみ
    elseif ($city) {
        $meta["province"] = $province
        $meta["city"]     = $city
    }
    # 郡 + 町 or 村
    elseif ($county -and ($town -or $village)) {
        $meta["province"] = $province
        $meta["county"]   = $county
        if ($town)   { $meta["town"]    = $town }
        if ($village){ $meta["village"] = $village }
    }
    else {
        if ($province) { $meta["province"] = $province }
    }

    return $meta
}




function Split-ByMunicipality {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlElement[]]$Trkpts
    )

    $doc = New-Object System.Xml.XmlDocument
    $groups = @{}

    foreach ($trkpt in $Trkpts) {
        $ext = $trkpt.extensions

        $province = $ext.province
        $city     = $ext.city
        $suburb   = $ext.suburb
        $county   = $ext.county
        $town     = $ext.town
        $village  = $ext.village

        $key = $null
        $meta = @{}

        # 東京23区などは city 単独で分類（suburbは町名なので無視）
        if ($city -and $city -match '区$') {
            $key = $city
            $meta = @{ city = $city }
            if ($province -and $province -ne "東京都") {
                $meta["province"] = $province
            }
        }
        # 市＋区（例：仙台市青葉区）
        elseif ($city -and $suburb) {
            $key = "$city/$suburb"
            $meta = @{ province = $province; city = $city; suburb = $suburb }
        }
        # 市のみ（例：横須賀市）
        elseif ($city) {
            $key = $city
            $meta = @{ province = $province; city = $city }
        }
        # 郡＋町村（例：耶麻郡猪苗代町）
        elseif ($county -and ($town -or $village)) {
            $area = $town ?? $village
            $key = "$county/$area"
            $meta = @{ province = $province; county = $county }
            if ($town)   { $meta["town"]    = $town }
            if ($village){ $meta["village"] = $village }
        }
        else {
            $key = "未分類"
            $meta = @{ province = $province }
        }

        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = @{
                trkpts = @()
                meta = $meta
            }
        }

        $groups[$key].trkpts += $trkpt
    }

    $trksegList = @()

    foreach ($group in $groups.Values) {
        $trkseg = $doc.CreateElement("trkseg")

        # <extensions> ノード構築
        $extNode = $doc.CreateElement("extensions")
        foreach ($tag in $group.meta.Keys) {
            $val = $group.meta[$tag]
            if ($val) {
                $node = $doc.CreateElement($tag)
                $node.InnerText = $val
                $extNode.AppendChild($node) | Out-Null
            }
        }
        $trkseg.AppendChild($extNode) | Out-Null

        # trkptノード追加
        foreach ($pt in $group.trkpts) {
            $trkseg.AppendChild($doc.ImportNode($pt, $true)) | Out-Null
        }

        $trksegList += $trkseg
    }

    return $trksegList
}