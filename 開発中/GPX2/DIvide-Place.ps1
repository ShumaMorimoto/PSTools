function Get-Muni {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $pt
    )

    if (-not $pt.extensions) {
        return $null
    }

    $ext      = $pt.extensions
    $province = $ext.province
    $city     = $ext.city
    $suburb   = $ext.suburb
    $county   = $ext.county
    $town     = $ext.town
    $village  = $ext.village

    # ordered ハッシュで順序を固定
    $meta = [ordered]@{}

    # 東京23区などは city 単独で分類（provinceは入れない）
    if ($city -and $city -match '区$') {
        $meta["city"] = $city
    }
    elseif ($city -and $suburb) {
        $meta["province"] = $province
        $meta["city"]     = $city
        $meta["suburb"]   = $suburb
    }
    elseif ($city) {
        $meta["province"] = $province
        $meta["city"]     = $city
    }
    elseif ($county -and ($town -or $village)) {
        $meta["province"] = $province
        $meta["county"]   = $county
        if ($town)   { $meta["town"]    = $town }
        if ($village){ $meta["village"] = $village }
    }
    else {
        $meta["province"] = $province
    }

    return $meta
}


function Group-PlacesByMuni {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Trkpts   # GPXの<trkpt>ノード配列
    )

    $groups = @{}

    foreach ($pt in $Trkpts) {
        $meta = Get-Muni $pt

        # meta=$nullなら未分類
        if (-not $meta) {
            $key = "未分類"
        }
        else {
            # metaのValueを連結してキーにする
            $key = ($meta.Values -join "/")
        }

        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = @()
        }
        $groups[$key] += $pt
    }

    # 戻り値は拠点配列の配列
    $result = @()
    foreach ($k in $groups.Keys) {
        $result += ,@($groups[$k])
        Write-Host ("[INFO] {0}: {1} 拠点" -f $k, $groups[$k].Count)
    }

    return ,$result
}