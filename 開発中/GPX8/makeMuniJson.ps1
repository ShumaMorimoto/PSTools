# ============================================
# DFP → municipalities.json（最終修正版）
# muniCd5 / muniCd6 / prefecture を統合
# DFP の code / prefecture_code が Int64 で返る前提でゼロ詰め復元
# ============================================

$endpoint = 'https://www.mlit-data.jp/api/v1/graphql'
$headers = @{
    "Content-Type" = "application/json"
    "apikey"       = "4ZiwH4ty7rcYPfye2sYP9DjX9BBjCOzY"
}

# -------------------------------
# ✅ 1. 都道府県一覧を取得
# -------------------------------
$prefQuery = @{
    query = @"
{
  prefecture {
    code
    name
  }
}
"@
} | ConvertTo-Json -Depth 5

$prefResponse = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $prefQuery

# prefecture_code → prefecture_name の辞書
$prefMap = @{}
foreach ($p in $prefResponse.data.prefecture) {

    # ✅ prefecture_code は Int → 2桁ゼロ詰め
    $prefCode = "{0:D2}" -f $p.code

    $prefMap[$prefCode] = $p.name
}

# -------------------------------
# ✅ 2. 自治体一覧を取得
# -------------------------------
$muniQuery = @{
    query = @"
{
  municipalities {
    code
    name
    prefecture_code
  }
}
"@
} | ConvertTo-Json -Depth 5

$muniResponse = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $muniQuery
$municipalities = $muniResponse.data.municipalities

# -------------------------------
# ✅ 3. muniCd6 をゼロ詰め復元 → muniCd5 を生成
# -------------------------------
$final = @()
foreach ($m in $municipalities) {

    # ✅ DFP の code は Int64 → 6桁ゼロ詰めで復元
    $muniCd6 = "{0:D6}" -f $m.code

    # ✅ muniCd5 は muniCd6 の先頭5桁
    $muniCd5 = $muniCd6.Substring(0,5)

    # ✅ prefecture_code も Int → 2桁ゼロ詰め
    $prefCode = "{0:D2}" -f $m.prefecture_code

    $final += @{
        muniCd5    = $muniCd5
        muniCd6    = $muniCd6
        municipality = $m.name
        prefecture = $prefMap[$prefCode]
        prefecture_code = $prefCode
    }
}

# -------------------------------
# ✅ 4. JSON として保存
# -------------------------------
@{
    municipalities = $final
} | ConvertTo-Json -Depth 10 | Out-File "municipalities.json" -Encoding utf8

Write-Host "✅ municipalities.json を生成しました（DFP 直叩き・Int64 完全対応）"