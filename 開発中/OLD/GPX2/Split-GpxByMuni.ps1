using module RouteOptimizer

function Split-GPXByMuni {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputFile
    )

    if (-not (Test-Path $InputFile)) {
        Write-Error "❌ ファイルが見つかりません: $InputFile"
        exit 1
    }

    try {
        # ① GPX読み込み
        $gpxDoc = [GPXDocument]::Load($InputFile)
        $trkpts = $gpxDoc.GetTrkPt()
        if (-not $trkpts) {
            Write-Warning "trkptが不足しています。分割できません。"
            exit 1
        }

        # ② 自治体ごとに分割
        $routes = Group-PlacesByMuni -Trkpts $trkpts

        # ③ 出力準備
        $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
        $outputDir = [System.IO.Path]::GetDirectoryName($InputFile)

        foreach ($trkptNodes in $routes) {
            # 新しいGPXDocumentを作成（元の構造をコピー）
            $newDoc = [GPXDocument]::LoadXml($gpxDoc.OuterXml)

            # 拠点を再設定
            $newDoc.SetTrkPt($trkptNodes)

            # meta取得
            $meta = Get-Muni $trkptNodes[0]

            # province以外を区切りなしで結合
            if ($meta) {
                $key = ($meta.GetEnumerator() | Where-Object { $_.Key -ne "province" } | ForEach-Object { $_.Value }) -join ''
            }
            else {
                $key = "未分類"
            }

            # トラック名設定
            $newDoc.SetTrkName("自治体分割 [$key]")

            # ファイル保存（自治体名ベース）
            $filename = [System.IO.Path]::Combine($outputDir, ("{0}-{1}.gpx" -f $baseName, $key))
            $newDoc.Save($filename)

            # 統計表示（拠点数のみ）
            $stats = $newDoc.GetStats()
            $pointCount = $stats.PointCount

            Write-Host "✅ 出力: $filename （拠点：$pointCount　自治体: $key）" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
    }
}