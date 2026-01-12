Write-Host "=== Cluster-Mesh TEST START ==="

# ---------------------------------------------------------
# 1. テスト用の Places（東京周辺の駅）
# ---------------------------------------------------------
$Places = @(
    [PSCustomObject]@{ Name="Tokyo";    Lat=35.681236; Lon=139.767125 }
    [PSCustomObject]@{ Name="Shinjuku"; Lat=35.689487; Lon=139.691711 }
    [PSCustomObject]@{ Name="Shibuya";  Lat=35.658034; Lon=139.701636 }
    [PSCustomObject]@{ Name="Ikebukuro";Lat=35.729503; Lon=139.710900 }
    [PSCustomObject]@{ Name="Akiba";    Lat=35.700167; Lon=139.774500 }
    [PSCustomObject]@{ Name="Ueno";     Lat=35.713768; Lon=139.777254 }
    [PSCustomObject]@{ Name="Ginza";    Lat=35.671669; Lon=139.765440 }
    [PSCustomObject]@{ Name="Meguro";   Lat=35.633998; Lon=139.715828 }
    [PSCustomObject]@{ Name="Kichijoji";Lat=35.703306; Lon=139.579502 }
    [PSCustomObject]@{ Name="Mitaka";   Lat=35.683514; Lon=139.559601 }
)

Write-Host "`n[INFO] Places loaded: $($Places.Count)"

# ---------------------------------------------------------
# 2. クラスタリング実行
# ---------------------------------------------------------
$clusters = Cluster-Mesh `
    -Places $Places `
    -MeshKm 5 `
    -MaxGroupSize 50

Write-Host "`n[INFO] Clusters returned: $($clusters.Count)"

# ---------------------------------------------------------
# 3. 結果表示（index と Name を両方表示）
# ---------------------------------------------------------
$clusterId = 1
foreach ($c in $clusters) {
    Write-Host "`n--- Cluster $clusterId (size=$($c.Count)) ---"

    foreach ($idx in $c) {
        Write-Host "[$idx] $($Places[$idx].Name)"
    }

    # クラスタの代表点（平均緯度経度）
    $latAvg = ($c | ForEach-Object { $Places[$_].Lat } | Measure-Object -Average).Average
    $lonAvg = ($c | ForEach-Object { $Places[$_].Lon } | Measure-Object -Average).Average
    Write-Host "Center: Lat=$([math]::Round($latAvg,5)), Lon=$([math]::Round($lonAvg,5))"

    $clusterId++
}

Write-Host "`n=== TEST END ==="