function Get-TownListFromLatLon {
    param (
        [Parameter(Mandatory = $true)][double]$lat,
        [Parameter(Mandatory = $true)][double]$lon,
        [Parameter()][string]$dfpApiKey = "4ZiwH4ty7rcYPfye2sYP9DjX9BBjCOzY"
    )

    # 1. GSI Reverse Geocoder
    $gsiUrl = "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$lat&lon=$lon"
    $gsiRes = Invoke-RestMethod -Uri $gsiUrl -Method Get
    $muniCd5 = $gsiRes.results.muniCd
    $prefFromGSI = $gsiRes.results.lv01Nm
    $cityFromGSI = $gsiRes.results.lv02Nm

    # 2. JIS X0402 チェックディジットで6桁化
    function Get-DFPCodeFromMuniCd {
        param ([string]$muniCd5)
        $weights = @(6,5,4,3,2)
        $sum = 0
        for ($i = 0; $i -lt 5; $i++) {
            $sum += [int]::Parse($muniCd5[$i]) * $weights[$i]
        }
        $cd = 11 - ($sum % 11)
        if ($cd -eq 10 -or $cd -eq 11) { $cd = 0 }
        return "$muniCd5$cd"
    }
    $muniCd6 = Get-DFPCodeFromMuniCd $muniCd5

    # 3. DFP API: 市区町村名・都道府県コード
    $endpoint = "https://www.mlit-data.jp/api/v1/graphql"
    $headers = @{ "Content-Type" = "application/json"; "apikey" = $dfpApiKey }
    $muniCdQuoted = '"' + $muniCd6 + '"'
    $query1 = @"
{
  municipalities(muniCodes: [$muniCdQuoted]) {
    name
    prefecture_code
  }
}
"@
    $body1 = @{ query = $query1 } | ConvertTo-Json -Depth 3
    $response1 = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body1
    $cityName = $response1.data.municipalities[0].name
    $prefCode = $response1.data.municipalities[0].prefecture_code

    # 4. DFP API: 都道府県名
    $query2 = @"
{
  prefecture {
    code
    name
  }
}
"@
    $body2 = @{ query = $query2 } | ConvertTo-Json -Depth 3
    $response2 = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body2
    $prefName = ($response2.data.prefecture | Where-Object { $_.code -eq $prefCode }).name

    # 5. Geolonia API: 町字一覧取得
    $townUrl = "https://geolonia.github.io/japanese-addresses/api/ja/$prefName/$cityName.json"
    try {
        $towns = Invoke-RestMethod -Uri $townUrl -Method Get
        return $towns
    } catch {
        Write-Warning "❌ 町字データの取得に失敗しました: $townUrl"
        return @()
    }
}