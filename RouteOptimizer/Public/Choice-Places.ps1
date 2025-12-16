function Choice-Places {
    param(
        [System.Xml.XmlElement[]]$Places = $null
    )

    # ============================
    # 1. 中心座標
    # ============================
    if ($Places -and $Places.Count -gt 0) {
        $CenterLat = $Places[0].lat
        $CenterLng = $Places[0].lon
    }
    else {
        $CenterLat = 35.0
        $CenterLng = 135.0
    }

    $Zoom = 16
    $Port = 5000

    # ============================
    # 2. HTML テンプレート
    # ============================
    $templatePath = Join-Path $script:ModuleRoot "data\map.html"
    $html = Get-Content $templatePath -Raw

    # ============================
    # 2.5. 新規ノード生成用 GPXDocument（毎回 new）
    # ============================
    $tempGpx = [GPXDocument]::new()

    # ============================
    # 3. XMLノード → JSON（ElementToPSO を使用）
    # ============================
    $jsonPoints = @()
    $i = 0

    foreach ($pt in ($Places ?? @())) {
        # GPX → PSO（汎用）
        $pso = [GPXDocument]::ElementToPSO($pt)

        # UI 用の id を後付け（内部限定）
        $pso["id"] = $i
        $jsonPoints += [PSCustomObject]$pso
        $i++
    }
    # Places が空のときも [] を埋め込む
    $mapJson = if ($jsonPoints.Count -eq 0) { '[]' } else { $jsonPoints | ConvertTo-Json -Depth 10 }

    # ============================
    # 4. HTML 埋め込み
    # ============================
    $html = $html.Replace('$CenterLat', $CenterLat)
    $html = $html.Replace('$CenterLng', $CenterLng)
    $html = $html.Replace('$Zoom', $Zoom)
    $html = $html.Replace('$MapData', $mapJson)

    # ============================
    # 5. HTTP サーバ
    # ============================
    $listener = [System.Net.HttpListener]::new()
    $prefix = "http://localhost:$Port/"
    $listener.Prefixes.Add($prefix)
    $listener.Start()

    $choice = $null

    Start-Process $prefix

    $stop = $false
    while (-not $stop) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $absPath = $req.Url.AbsolutePath
        $localPath = $null # 追加

        if ($absPath -eq '/') {
            # map.html の処理（変更なし）
            $bytes = [Text.Encoding]::UTF8.GetBytes($html)
            $res.ContentType = 'text/html; charset=utf-8'
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.Close()
        }
        elseif ($absPath.StartsWith('/js/') -and (-not $absPath.Contains('..'))) {
            # 追加: /js/ ディレクトリ内のファイルをホストする汎用処理
        
            # URLパスをローカルファイルパスに変換
            # 例: /js/your_script.js -> data\js\your_script.js
            $relativePath = $absPath.Substring(1).Replace('/', '\')
            $localPath = Join-Path $script:ModuleRoot "data\$relativePath"

            if (Test-Path $localPath -PathType Leaf) {
                $bytes = [System.IO.File]::ReadAllBytes($localPath)
                $res.ContentType = 'application/javascript; charset=utf-8'
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
            }
            else {
                # ファイルが見つからない場合
                $res.StatusCode = 404
                $res.Close()
            }
        }
        elseif ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/choice') {

            $reader = [System.IO.StreamReader]::new($req.InputStream)
            $body = $reader.ReadToEnd()
            $reader.Close()

            if ($body) {
                $choice = $body | ConvertFrom-Json
            }

            $res.StatusCode = 200
            $res.Close()

        }
        elseif ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/done') {

            $stop = $true
            $res.StatusCode = 200
            $res.Close()

        }
        else {
            $res.StatusCode = 404
            $res.Close()
        }
    }

    try { $listener.Stop() } catch {}

    # ============================
    # 6. choice が無い → 元のノードを返す
    # ============================
    if (-not $choice) {
        return , ($Places ?? @())
    }

    # ============================
    # 8. 元ノード辞書
    # ============================
    $trkptIndex = @{}
    $i = 0
    foreach ($pt in ($Places ?? @())) {
        $trkptIndex[$i] = $pt
        $i++
    }

    # ============================
    # 9. JSON → trkpt ノード再構築
    # ============================
    $newTrkpts = @()

    foreach ($e in $choice) {

        if ($e.id -ne $null -and $trkptIndex.ContainsKey($e.id)) {

            # --- 既存ノード更新 ---
            $orig = $trkptIndex[$e.id]
            $new = $orig.CloneNode($true)

            $new.SetAttribute("lat", $e.lat)
            $new.SetAttribute("lon", $e.lon)

            $nameNode = $new.SelectSingleNode("gpx:name", [GPXDocument]::NamespaceManager)
            if (-not $nameNode) {
                $nameNode = $new.OwnerDocument.CreateElement("name", [GPXDocument]::GpxNamespace)
                $new.AppendChild($nameNode) | Out-Null
            }
            $nameNode.InnerText = $e.name

            $descNode = $new.SelectSingleNode("gpx:desc", [GPXDocument]::NamespaceManager)
            if (-not $descNode) {
                $descNode = $new.OwnerDocument.CreateElement("desc", [GPXDocument]::GpxNamespace)
                $new.AppendChild($descNode) | Out-Null
            }
            $descNode.InnerText = $e.desc

            $extNode = $new.SelectSingleNode("gpx:extensions", [GPXDocument]::NamespaceManager)
            if (-not $extNode) {
                $extNode = $new.OwnerDocument.CreateElement("extensions", [GPXDocument]::GpxNamespace)
                $new.AppendChild($extNode) | Out-Null
            }

            foreach ($key in $e.extended.Keys) {
                $child = $extNode.SelectSingleNode("gpx:$key", [GPXDocument]::NamespaceManager)
                if ($child) {
                    $child.InnerText = $e.extended[$key]
                }
                else {
                    $child = $new.OwnerDocument.CreateElement($key, [GPXDocument]::GpxNamespace)
                    $child.InnerText = $e.extended[$key]
                    $extNode.AppendChild($child) | Out-Null
                }
            }
            $newTrkpts += $new
        }
        else {

            # --- 新規追加（毎回 new GPXDocument() で生成） ---
            $pso = [PSCustomObject]@{
                lat        = $e.lat
                lon        = $e.lon
                name       = $e.name
                desc       = $e.desc
                extensions = $e.extended
            }
            $new = $tempGpx.CreateElementFromPSO("trkpt", $pso)
            $newTrkpts += $new
        }
    }
    return , $newTrkpts
}