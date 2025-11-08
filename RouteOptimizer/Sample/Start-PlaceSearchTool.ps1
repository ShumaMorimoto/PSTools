function Start-PlaceSearchTool {
    while ($true) {
        Write-Host "`n🔍 地名キーワードを入力してください（終了するには q を入力）:" -ForegroundColor Cyan
        $keyword = Read-Host "Keyword"

        if ($keyword -eq 'q') {
            Write-Host "✅ ツールを終了します。" -ForegroundColor Yellow
            break
        }

        $trkpts = Search-Place -Keyword $keyword
        if (-not $trkpts -or $trkpts.Count -eq 0) {
            Write-Warning "検索結果が見つかりませんでした。"
            continue
        }

        # 表示用に整形
        $results = $trkpts | ForEach-Object {
            $name = $_.SelectSingleNode("name").InnerText
            $lat = $_.GetAttribute("lat")
            $lon = $_.GetAttribute("lon")
            $desc = $_.SelectSingleNode("desc").InnerText
            [PSCustomObject]@{
                Name        = $name
                Municipality = $desc -split ',' | Where-Object { $_ -match '市|区|町|村' } | Select-Object -First 1
                Latitude    = $lat
                Longitude   = $lon
            }
        }

        # 結果表示
        Write-Host "`n📍 検索結果一覧:" -ForegroundColor Green
        $results | Format-Table -AutoSize

        # 選択
        Write-Host "`nコピーしたい番号を選択してください（0〜$($results.Count - 1)、スキップは Enter）:" -ForegroundColor Cyan
        $index = Read-Host "Index"
        if ($index -match '^\d+$' -and [int]$index -lt $results.Count) {
            $selected = $results[$index]
            $text = "$($selected.Latitude),$($selected.Longitude)"
            Set-Clipboard -Value $text
            Write-Host "📋 クリップボードにコピーしました: $text" -ForegroundColor Green
        }
        else {
            Write-Host "⏭ スキップしました。" -ForegroundColor DarkGray
        }
    }
}