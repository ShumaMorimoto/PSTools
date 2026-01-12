# --- 設定 ---
$inputGpx = "C:\Users\shuma\OneDrive\ドキュメント\【周辺】越前市①.gpx"
$outputGpx = Join-Path $env:TEMP "verified_output.gpx"

Write-Host "--- GPX 整合性テスト開始 ---" -ForegroundColor Cyan

# 1. ファイルからロード
$gpx = [GPXService]::FromFile($inputGpx)
Write-Host "Original Creator: $($gpx.Model.creator)"
Write-Host "Original Version: $($gpx.Model.version)"

# 2. モデルの書き出しと再読み込み (Model Roundtrip)
$modelHash = $gpx.ToModel()
$gpxFromModel = [GPXService]::new($modelHash)

# 3. ファイルへの保存 (インデント・XML宣言の確認)
$gpxFromModel.Save($outputGpx)
Write-Host "Saved verified XML to: $outputGpx"

# 4. 内容の比較検証
Write-Host "`n--- 検証レポート ---" -ForegroundColor Yellow
$newXml = [xml](Get-Content $outputGpx -Raw)

# A. XML宣言の確認
$hasDecl = (Get-Content $outputGpx -TotalCount 1) -match '<\?xml'
Write-Host "XML Declaration Check: $(if($hasDecl){'OK'}else{'NG'})" -ForegroundColor $(if($hasDecl){'Green'}else{'Red'})

# B. ルート属性の確認
$rootVersion = $newXml.gpx.version
$rootCreator = $newXml.gpx.creator
Write-Host "Root Attribute (version): $rootVersion" -ForegroundColor $(if($rootVersion -eq "1.1"){'Green'}else{'Red'})
Write-Host "Root Attribute (creator): $rootCreator" -ForegroundColor $(if($rootCreator){'Green'}else{'Red'})

# C. 地点データの数と型の確認
$origPoints = $gpx.GetTrkpts()
$newPoints = $newXml.gpx.trk.trkseg.trkpt
Write-Host "Point Count Match: $($origPoints.Count) == $($newPoints.Count)" -ForegroundColor $(if($origPoints.Count -eq $newPoints.Count){'Green'}else{'Red'})

# D. 型キャストの確認 (lat/lon が数値として保存・復元されているか)
$firstPt = $origPoints[0]
if ($firstPt.lat -is [double]) {
    Write-Host "Type Check (lat is Double): OK" -ForegroundColor Green
}

# 5. JSON 変換のテスト
Write-Host "`n--- JSON 連携テスト ---" -ForegroundColor Yellow
$json = $gpx.ToJson()
$gpxFromJson = [GPXService]::new()
$gpxFromJson.LoadJson($json)
Write-Host "JSON Load Success: $($gpxFromJson.Model.trk.name)" -ForegroundColor Green

Write-Host "`nテスト完了。出力ファイルを確認してください。"
# notepad $outputGpx