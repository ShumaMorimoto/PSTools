using module RouteOptimizer

$FilePath = "D:\tool\log\SearchPlaceLog.gpx"

function Start-PlaceSearchTool {
    function Write-PlaceLog {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [System.Xml.XmlElement]$Trkpt
        )

        # 履歴ファイルがなければ初期化
        if (-not (Test-Path $FilePath)) {
            $doc = [GPXDocument]::new("PlaceSearchTool", "SearchPlaceLog")
            $doc.Save($FilePath)
        }

        # 履歴ファイル読み込み
        $doc = [GPXDocument]::Load($FilePath)

        # trkptノードを追加（AddTrkPtNodeを利用）
        $doc.AddTrkPtNode($Trkpt)

        # 保存
        $doc.Save($FilePath)
    }

    while ($true) {
        Write-Host "`n🔍 地名キーワードを入力してください（終了するには q を入力）:" -ForegroundColor Cyan
        $keyword = Read-Host "Keyword"

        if ($keyword -eq 'q') {
            Write-Host "✅ ツールを終了します。" -ForegroundColor Yellow
            break
        }

        $trkpts = (Search-Places -Keyword $keyword).GetTrkPt()
        if (-not $trkpts -or $trkpts.Count -eq 0) {
            Write-Warning "検索結果が見つかりませんでした。"
            continue
        }

        # 表示用に整形
        $results = $trkpts | ForEach-Object -Begin { $i = 0 } -Process {
            $name = $_.name
            $lat = $_.lat
            $lon = $_.lon
            $desc = $_.desc

            # extensions/townname を取得
            $townnameNode = $_.extensions.townname
            $municipality = $townnameNode ?? 'Unknown'

            [PSCustomObject]@{
                Index     = $i++
                Name      = $name
                所在地       = $municipality
                Latitude  = $lat
                Longitude = $lon
            }
        }

        # 結果表示
        Write-Host "`n📍 検索結果一覧:" -ForegroundColor Green
        $results | Format-Table -AutoSize

        # 選択
        if ($results.Count -eq 1) {
            $selected = $results[0]
            $text = "$($selected.Latitude),$($selected.Longitude)"
            Set-Clipboard -Value $text
            Write-PlaceLog -FilePath $FilePath -Trkpt $trkpts
            Write-Host "`n📋 検索結果が1件のため自動的にコピーしました: $text" -ForegroundColor Green
        }
        else {
            Write-Host "`nコピーしたい番号を選択してください（0〜$($results.Count - 1)、スキップは Enter）:" -ForegroundColor Cyan
            $index = Read-Host "Index"
            if ($index -match '^\d+$' -and [int]$index -lt $results.Count) {
                $selected = $results[$index]
                $text = "$($selected.Latitude),$($selected.Longitude)"
                Set-Clipboard -Value $text
                Write-PlaceLog -FilePath $FilePath -Trkpt $trkpts[$index]
                Write-Host "📋 クリップボードにコピーしました: $text" -ForegroundColor Green
            }
            else {
                Write-Host "⏭ スキップしました。" -ForegroundColor DarkGray
            }
        }
    }
}

Start-PlaceSearchTool
