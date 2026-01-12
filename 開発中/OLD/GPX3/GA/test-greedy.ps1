Write-Host "=== Greedy Route Test (lat/lon) ==="

# -----------------------------
# 1. テスト用の Places（lat/lon）
# -----------------------------
$Places = @(
    [PSCustomObject]@{ Name = "Tokyo";    Lat = 35.681236; Lon = 139.767125 }  # 東京駅
    [PSCustomObject]@{ Name = "Shinjuku"; Lat = 35.689487; Lon = 139.691711 }  # 新宿駅
    [PSCustomObject]@{ Name = "Shibuya";  Lat = 35.658034; Lon = 139.701636 }  # 渋谷駅
    [PSCustomObject]@{ Name = "Ikebukuro";Lat = 35.729503; Lon = 139.710900 }  # 池袋駅
    [PSCustomObject]@{ Name = "Akiba";    Lat = 35.700167; Lon = 139.774500 }  # 秋葉原駅
)

# -----------------------------
# 2. 距離行列を生成（あなたの New-DistanceMatrix を使用）
# -----------------------------
$dist = New-DistanceMatrix -Places $Places

Write-Host "`nDistance Matrix Ready."

# -----------------------------
# 3. 全体 Greedy のテスト
# -----------------------------
$route1 = Get-GreedyRoute -DistanceMatrix $dist

Write-Host "`nGreedy Route (All):"
$route1 | ForEach-Object { "$_ : $($Places[$_].Name)" }

# -----------------------------
# 4. Route 全体 Greedy のテスト
# -----------------------------
$route2 = Get-GreedyRoute -DistanceMatrix $dist -Route $route1

Write-Host "`nGreedy Route (Re-run on Route):"
$route2 | ForEach-Object { "$_ : $($Places[$_].Name)" }

# -----------------------------
# 5. 区間 Greedy のテスト
# -----------------------------
# 例として区間 1〜3 を最適化
$route3 = Get-GreedyRoute `
    -DistanceMatrix $dist `
    -Route $route1 `
    -StartPos 1 `
    -EndPos 3

Write-Host "`nGreedy Route (Segment 1-3 Optimized):"
$route3 | ForEach-Object { "$_ : $($Places[$_].Name)" }