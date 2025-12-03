$input = Read-Host "都市名を入力してください（例：中央区、生駒市）"

$query = @"
[out:json];
relation["boundary"="administrative"]["name"~"$input"]["admin_level"~"7|8|9"];
out tags;
"@

$response = Invoke-RestMethod -Uri "https://overpass-api.de/api/interpreter" -Method Post -Body $query

if ($response.elements.Count -eq 0) {
    Write-Host "❌ 候補が見つかりませんでした。"
    exit
}

# 候補表示（上位都市名も推定表示）
Write-Host "✅ 候補一覧:"
$response.elements | ForEach-Object -Begin { $i = 0 } -Process {
    $name = $_.tags.name
    $level = $_.tags.admin_level
    $parent = $_.tags."is_in" ?? $_.tags."addr:city" ?? $_.tags."addr:province" ?? "（上位不明）"
    Write-Host "[$i] $name（admin_level=$level, 上位=$parent）"
    $i++
}

# ユーザー選択
$choice = Read-Host "番号を選択してください"
$selected = $response.elements[$choice]
$areaId = 3600000000 + $selected.id