<#
.SYNOPSIS
    指定された地名キーワードに基づいて、その地域の町字一覧を取得します。
.DESCRIPTION
    Nominatim APIで地名の候補を検索し、ユーザーが選択した地域の町字（neighbourhood）の一覧と座標を出力します。
.PARAMETER Keyword
    検索したい地名キーワードを指定します。（例: "横浜", "渋谷"）
.EXAMPLE
    .\Get-Towns.ps1 -Keyword "横浜"
#>

# ================================
# スクリプトの引数設定
# ================================
param(
    [Parameter(Mandatory = $true, HelpMessage = "検索したい地名キーワードを入力してください。")]
    [string]$keyword
)

# ================================
# 設定
# ================================
$nominatimUrl = "https://nominatim.openstreetmap.org/search"
$overpassUrl = "https://overpass-api.de/api/interpreter"

# ================================
# 1. Nominatimで地名検索 → 候補を最大10件取得
# ================================
Write-Host "🔍 Nominatimで地名検索中: $keyword"

$nominatimParams = @{
    q              = $keyword
    format         = "json"
    addressdetails = 1
    limit          = 10  # 最大10件まで取得
}

try {
    $nominatimResult = Invoke-RestMethod -Uri $nominatimUrl -Method Get -Body $nominatimParams -ErrorAction Stop
}
catch {
    Write-Error "Nominatim APIへのアクセス中にエラーが発生しました: $($_.Exception.Message)"
    exit
}

if (-not $nominatimResult) {
    Write-Error "地名が見つかりませんでした: '$keyword'"
    exit
}

# ================================
# 2. 候補が複数ある場合はユーザーに選択させる
# ================================
$targetLocation = $null

# 取得結果が単一オブジェクトの場合でも配列として扱えるように @() で囲む
if (@($nominatimResult).Count -eq 1) {
    $targetLocation = $nominatimResult[0]
    Write-Host "✅ 候補が1件見つかりました。この候補で処理を続行します。" -ForegroundColor Green
}
else {
    Write-Host "🗺️ 複数の候補が見つかりました。処理を続ける候補の番号を入力してください。" -ForegroundColor Yellow
    
    # 候補を番号付きで一覧表示
    for ($i = 0; $i -lt @($nominatimResult).Count; $i++) {
        $item = $nominatimResult[$i]
        # 整形して表示: 例 " 1: 神奈川県横浜市, 日本"
        Write-Host (" {0,2}: {1}" -f ($i + 1), $item.display_name)
    }

    # ユーザーからの正しい入力があるまでループ
    while ($true) {
        $input = Read-Host "番号を入力 (1-$(@($nominatimResult).Count)), または 'q' で終了"
        
        if ($input -eq 'q') {
            Write-Host "処理を中断しました。"
            exit
        }

        if (($input -match '^\d+$') -and ([int]$input -ge 1) -and ([int]$input -le @($nominatimResult).Count)) {
            $selectedIndex = [int]$input - 1
            $targetLocation = $nominatimResult[$selectedIndex]
            break
        }
        else {
            Write-Warning "無効な入力です。1から $(@($nominatimResult).Count) までの半角数値を入力してください。"
        }
    }
}

# ================================
# 3. 選択された候補の情報で後続処理を実行
# ================================
$lat = $targetLocation.lat
$lon = $targetLocation.lon
$displayName = $targetLocation.display_name

Write-Host "`n" + ("-" * 50)
Write-Host "📍 選択された候補: $displayName"
Write-Host "🌍 座標: $lat, $lon"
Write-Host ("-" * 50)

# ================================
# 4. Overpassで座標から自治体のrelation ID取得
# ================================
Write-Host "`n📡 Overpassで自治体relation ID取得中..."

$overpassQuery = @"
[out:json];
is_in($lat,$lon)->.a;
rel(pivot.a)["boundary"="administrative"]["admin_level"~"^[6-8]$"];
out ids;
"@

$relationResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $overpassQuery
$relation = $relationResult.elements | Sort-Object { [int]$_.tags.admin_level } -Descending | Select-Object -First 1
$relationId = $relation.id

if (-not $relationId) {
    Write-Error "自治体のrelation IDが取得できませんでした。別の候補で試してみてください。"
    exit
}

Write-Host "🆔 relation ID: $relationId"

# ================================
# 5. relation ID → area IDに変換
# ================================
$areaId = 3600000000 + $relationId
Write-Host "🌐 area ID: $areaId"

# ================================
# 6. 町字一覧取得（neighbourhood）
# ================================
Write-Host "`n📋 町字一覧取得中..."

$townQuery = @"
[out:json][timeout:25];
area($areaId)->.target;
(
  node(area.target)["place"="neighbourhood"];
  way(area.target)["place"="neighbourhood"];
  relation(area.target)["place"="neighbourhood"];
);
out body;
"@

$townResult = Invoke-RestMethod -Uri $overpassUrl -Method Post -Body $townQuery
$towns = $townResult.elements | Where-Object { $_.tags.name } | Sort-Object { $_.tags.name }

if ($towns) {
    $towns | ForEach-Object {
        $townLat = if ($_.lat) { $_.lat } else { $_.center.lat }
        $townLon = if ($_.lon) { $_.lon } else { $_.center.lon }
        Write-Host " $($_.tags.name)  📍`($townLat, $townLon`)"
    }
    Write-Host "`n✅ 取得した町字数: $($towns.Count)" -ForegroundColor Green
}
else {
    Write-Host "ℹ️ このエリアには 'neighbourhood' として登録されている町字が見つかりませんでした。"
}
