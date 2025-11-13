using module RouteOptimizer

function Update-GpxPlaceInfo {
    param (
        [Parameter(Mandatory)]
        [string]$GpxPath,

        [Parameter()]
        [string]$OutputPath = "$GpxPath.updated.gpx"
    )

    # GPX読み込み
    $xml = [xml](Get-Content $GpxPath -Raw)
    $trkpts = $xml.gpx.trk.trkseg.trkpt

    foreach ($trkpt in $trkpts) {
        $lat = [double]$trkpt.lat
        $lon = [double]$trkpt.lon

        Write-Host "🔄 $lat,$lon を更新中..." -ForegroundColor Cyan
        $newNode = Get-Place -Latitude $lat -Longitude $lon
        if ($newNode) {
            # 既存ノードを置き換え
            $trkpt.RemoveAll()  # 子要素削除
            $trkpt.SetAttribute("lat", $lat.ToString())
            $trkpt.SetAttribute("lon", $lon.ToString())

            foreach ($child in $newNode.ChildNodes) {
                $imported = $xml.ImportNode($child, $true)
                $trkpt.AppendChild($imported) | Out-Null
            }
        }
    }

    # 保存
    $xml.Save($OutputPath)
    Write-Host "✅ 更新完了: $OutputPath" -ForegroundColor Green
}