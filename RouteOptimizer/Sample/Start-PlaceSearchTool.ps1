using module RouteOptimizer

$FilePath = "D:\tool\log\SearchPlaceLog.xml"
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
            $doc = New-Object System.Xml.XmlDocument
            $gpx = $doc.CreateElement("gpx")
            $gpx.SetAttribute("version", "1.1")
            $gpx.SetAttribute("creator", "PlaceSearchTool")
            $doc.AppendChild($gpx) | Out-Null

            $trk = $doc.CreateElement("trk")
            $gpx.AppendChild($trk) | Out-Null

            $trkseg = $doc.CreateElement("trkseg")
            $trk.AppendChild($trkseg) | Out-Null

            $doc.Save($FilePath)
        }

        # 履歴ファイル読み込み
        $doc = New-Object System.Xml.XmlDocument
        $doc.Load($FilePath)
        $trkseg = $doc.SelectSingleNode("//trkseg")

        # trkptノードをインポートして追加
        $imported = $doc.ImportNode($Trkpt, $true)
        $trkseg.AppendChild($imported) | Out-Null

        $doc.Save($FilePath)
    }

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
        $results = $trkpts | ForEach-Object -Begin { $i = 0 } -Process {
            $name = $_.SelectSingleNode("name").InnerText
            $lat = $_.GetAttribute("lat")
            $lon = $_.GetAttribute("lon")
            $desc = $_.SelectSingleNode("desc").InnerText

            # extensions/townname を取得
            $townnameNode = $_.SelectSingleNode("extensions/townname")
            $municipality = if ($townnameNode) { $townnameNode.InnerText } else { "Unknown" }

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