function Transform-Gpx {
    param (
        [xml]$GpxXml
    )

    # 名前空間の設定
    $nsUri = "http://www.topografix.com/GPX/1/0"
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($GpxXml.NameTable)
    $nsMgr.AddNamespace("gpx", $nsUri)

    # 不要ノードの削除
    $nodesToRemove = @("//gpx:time", "//gpx:bounds", "//gpx:wpt")
    foreach ($xpath in $nodesToRemove) {
        $node = $GpxXml.SelectSingleNode($xpath, $nsMgr)
        if ($node) {
            $node.ParentNode.RemoveChild($node) | Out-Null
        }
    }

    # <trk> ノード取得
    $trkNode = $GpxXml.SelectSingleNode("//gpx:trk", $nsMgr)
    if (-not $trkNode) {
        throw "GPX に <trk> ノードが存在しません。"
    }

    # 新しい GPX ドキュメント作成
    $newDoc = New-Object System.Xml.XmlDocument
    $gpxRoot = $newDoc.CreateElement("gpx")
    $gpxRoot.SetAttribute("version", "1.0")
    $gpxRoot.SetAttribute("creator", "GPSBabel - https://www.gpsbabel.org")
    $gpxRoot.SetAttribute("xmlns", $nsUri)
    $null = $newDoc.AppendChild($gpxRoot)

    # <trk> ノードをインポート
    $importedTrk = $newDoc.ImportNode($trkNode, $true)

    # <trkpt> ノード処理
    $trkpts = $importedTrk.SelectNodes(".//gpx:trkpt", $nsMgr)
    foreach ($trkpt in $trkpts) {
        # <ele> ノード削除
        $eleNode = $trkpt.SelectSingleNode("gpx:ele", $nsMgr)
        if ($eleNode) {
            $trkpt.RemoveChild($eleNode) | Out-Null
        }
        # multiRoute 属性追加
        $trkpt.SetAttribute("multiRoute", "1")
    }

    $null = $gpxRoot.AppendChild($importedTrk)

    return [System.Xml.XmlDocument]$newDoc
}


$GpxInputPath = "d:\tool\a.kml"
# メイン処理
try {
    if (-not (Test-Path $GpxInputPath)) {
        throw "指定された GPX ファイルが存在しません: $GpxInputPath"
    }

    Write-Host "📂 GPX 読み込み中: $GpxInputPath"
    [xml]$gpxXml = Get-Content $GpxInputPath -Raw

    Write-Host "🔧 フォーマット変換中..."
    $newGpxDoc = Transform-Gpx -GpxXml $gpxXml

    # 型確認（安全性チェック）
    if ($newGpxDoc -isnot [System.Xml.XmlDocument]) {
        throw "返されたオブジェクトが XmlDocument ではありません。型: $($newGpxDoc.GetType().FullName)"
    }

    $outputPath = Join-Path (Split-Path $GpxInputPath) "converted.gpx"
    Write-Host "💾 出力中: $outputPath"
    
    ##    $newGpxDoc.Save($outputPath)

    Write-Host "✅ 変換完了"
}
catch {
    Write-Error "❌ エラー: $_"
}