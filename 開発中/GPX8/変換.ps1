# ファイルパスの設定
$gpxPath = "C:\Users\shuma\OneDrive\ドキュメント\検索履歴.gpx"
$jsonPath = "D:\tool\municipalities.json"
$outputPath = "output.gpx"


# 1. データの読み込み
if (!(Test-Path $gpxPath)) { Write-Error "GPXファイルが見つかりません"; exit }
[xml]$gpx = Get-Content $gpxPath
$master = Get-Content $jsonPath -Raw | ConvertFrom-Json
$muniMap = @{}
foreach ($item in $master.municipalities) { $muniMap[$item.muniCd5] = $item }

# 2. 名前空間
$ns = New-Object Xml.XmlNamespaceManager($gpx.NameTable)
$ns.AddNamespace("g", "http://www.topografix.com/GPX/1/1")
$trkpts = $gpx.SelectNodes("//g:trkpt", $ns)

# --- ヘルパー関数: 安全にテキストを取得しログを出す ---
function Get-SafeText {
    param($parentNode, $tagName, $default = "")
    if ($null -eq $parentNode) { return $default }
    $node = $parentNode.Item($tagName)
    if ($null -eq $node -or [string]::IsNullOrEmpty($node.InnerText)) {
        return $default
    }
    return $node.InnerText.Trim()
}

Write-Host "--- 処理開始: 合計 $($trkpts.Count) 件 ---" -ForegroundColor Cyan

$idx = 0
foreach ($pt in $trkpts) {
    $idx++
    $lat = $pt.Attributes["lat"].Value
    $lon = $pt.Attributes["lon"].Value
    
    # 3. データの退避 (ログ出力付き)
    $name      = Get-SafeText $pt "name" "名称未設定"
    $extNode   = $pt.Item("extensions", "http://www.topografix.com/GPX/1/1")
    $keyword   = Get-SafeText $extNode "keyword" ""
    $rawCount  = Get-SafeText $extNode "count" "1"
    $count     = ($rawCount -replace "\[object Object\]", "").Trim()
    if ([string]::IsNullOrEmpty($count)) { $count = "1" }
    $timestamp = Get-SafeText $extNode "timestamp" (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

    Write-Host "[$idx] $name ($lat, $lon)" -ForegroundColor Yellow
    Write-Host "   > 保持データ: keyword='$keyword', count='$count', timestamp='$timestamp'" -ForegroundColor Gray

    # 4. 地理院逆ジオコーダーAPI (正しいURL)
    $apiUrl = "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$lat&lon=$lon"
    $muniCd5 = ""
    $townNm = ""
    
    try {
        Start-Sleep -Milliseconds 200 # 連打防止
        $res = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 10
        if ($res.results) {
            $muniCd5 = $res.results.muniCd
            $townNm  = $res.results.lv01Nm
            Write-Host "   > API成功: muniCd5='$muniCd5', town='$townNm'" -ForegroundColor Green
        } else {
            Write-Host "   > API結果なし(海域など)" -ForegroundColor Magenta
        }
    } catch {
        Write-Host "   > API通信エラー: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 5. マスタ照会
    $muniData = $muniMap[$muniCd5]
    $pref = if ($muniData) { $muniData.prefecture } else { "" }
    $muni = if ($muniData) { $muniData.municipality } else { "" }
    $descText = "$pref$muni$townNm"
    Write-Host "   > 解決住所: $descText" -ForegroundColor White

    # 6. ノードのリセットと再構築
    # name以外を削除
    $toRemove = @()
    foreach($node in $pt.ChildNodes) { if($node.LocalName -ne "name") { $toRemove += $node } }
    foreach($node in $toRemove) { [void]$pt.RemoveChild($node) }

    # 各要素追加
    $newDesc = $gpx.CreateElement("desc", "http://www.topografix.com/GPX/1/1")
    $newDesc.InnerText = $descText
    $pt.AppendChild($newDesc) | Out-Null

    $newExt = $gpx.CreateElement("extensions", "http://www.topografix.com/GPX/1/1")
    $fields = @(
        @("keyword", $keyword),
        @("muniCd5", $muniCd5),
        @("town", $townNm),
        @("prefecture", $pref),
        @("municipality", $muni),
        @("count", $count),
        @("timestamp", $timestamp)
    )

    foreach ($f in $fields) {
        $node = $gpx.CreateElement($f[0], "http://www.topografix.com/GPX/1/1")
        $node.InnerText = $f[1]
        $newExt.AppendChild($node) | Out-Null
    }
    $pt.AppendChild($newExt) | Out-Null
}

# 8. 保存
$gpx.Save($outputPath)
Write-Host "`n--- すべての処理が完了しました ---" -ForegroundColor Cyan
Write-Host "出力ファイル: $outputPath"