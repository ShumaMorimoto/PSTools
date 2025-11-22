function Optimize-AreaRoute {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Places,
        [double]$DistanceKm = 3.0,
        [int]$PointLimit = 50,
        [int]$PopulationSize = 50,
        [int]$Generations = 100
    )

    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()

    # 🟡 クラスタ化前の初期距離を計算
    $initialDistance = 0.0
    for ($i = 0; $i -lt $Places.Count - 1; $i++) {
        $initialDistance += Get-Distance $Places[$i] $Places[$i + 1]
    }


    # ① グリッドクラスタリング
    $clusters = Group-Places $Places -MaxDistanceKm $DistanceKm -MaxGroupSize $PointLimit

    # ② クラスタ重心算出
    $centroids = foreach ($cluster in $clusters) {
        $latAvg = ($cluster | ForEach-Object { [double]$_.lat } | Measure-Object -Average).Average
        $lonAvg = ($cluster | ForEach-Object { [double]$_.lon } | Measure-Object -Average).Average
        [PSCustomObject]@{
            Lat    = $latAvg
            Lon    = $lonAvg
            Points = $cluster
        }
    }

    # ③ クラスタ順序決定（Nearest Neighbor）
    $ordered = Optimize-Route $centroids 

    # ④ クラスタ内ルート最適化（ベース関数使用）
    $finalRoute = @()
    for ($i = 0; $i -lt $ordered.Count; $i++) {
        $cluster = $ordered[$i]
        $start = if ($finalRoute.Count -gt 0) { $finalRoute[-1] } else { $null }

        $optimized = Optimize-Route -Places $cluster.Points -StartLocation $start -RouteMode "Open" `
            -PopulationSize 10 -Generations 50

        $finalRoute += $optimized
    }

    $totalDistance = 0.0
    for ($i = 0; $i -lt $finalRoute.Count - 1; $i++) {
        $totalDistance += Get-Distance $finalRoute[$i] $finalRoute[$i + 1]
    }

    # 実行時間と最終距離をログ出力
    Write-Host "`n🛤 クラスタ化前の初期ルート距離" -ForegroundColor Yellow
    Write-Host "📏 初期距離（順番そのまま）: $([math]::Round($initialDistance, 3)) km"
    Write-Host "`n🚀 最適化完了" -ForegroundColor Green
    Write-Host "📏 最適化後の総距離: $([math]::Round($totalDistance, 3)) km"
    Write-Host "⏱ 実行時間: $([math]::Round($elapsed.Elapsed.TotalSeconds, 2)) 秒"

    return $finalRoute
}