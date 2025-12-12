function Choice-Places {
    param(
        [hashtable]$Place = $null
    )

    # --- 中心座標 ---
    if ($Place) {
        $CenterLat = $Place.lat
        $CenterLng = $Place.lon
    }
    else {
        $CenterLat = 35.0
        $CenterLng = 135.0
    }

    $Zoom = 14
    $Port = 5000

    # --- HTMLテンプレート読み込み ---
    # --- HTMLテンプレート読み込み ---
    $templatePath = "D:\tool\Repository\PSTools\RouteOptimizer\data\map.html"
    $html = Get-Content $templatePath -Raw

    # --- テンプレート変数置換 ---
    $html = $html.Replace('$CenterLat', $CenterLat)
    $html = $html.Replace('$CenterLng', $CenterLng)
    $html = $html.Replace('$Zoom', $Zoom)

    # --- HTTP サーバ起動 ---
    $listener = [System.Net.HttpListener]::new()
    $prefix = "http://localhost:$Port/"
    $listener.Prefixes.Add($prefix)
    $listener.Start()

    # --- 選択点リスト ---
    $points = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --- ブラウザで開く ---
    Start-Process $prefix

    # --- リッスンループ ---
    $stop = $false
    while (-not $stop) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request; $res = $ctx.Response

        if ($req.HttpMethod -eq 'GET' -and $req.Url.AbsolutePath -eq '/') {
            $bytes = [Text.Encoding]::UTF8.GetBytes($html)
            $res.ContentType = 'text/html; charset=utf-8'
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.Close()
        }
        elseif ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/click') {
            $reader = [System.IO.StreamReader]::new($req.InputStream)
            $body = $reader.ReadToEnd(); $reader.Close()

            if ($body) {
                $data = $body | ConvertFrom-Json
                $points.Add([PSCustomObject]@{
                        Lat = [double]$data.lat
                        Lon = [double]$data.lon   # ← GPX仕様に合わせて Lon
                    })
            }

            $res.StatusCode = 200; $res.Close()
        }
        elseif ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/done') {
            $stop = $true
            $res.StatusCode = 200; $res.Close()
        }
        else {
            $res.StatusCode = 404; $res.Close()
        }
    }

    try { $listener.Stop() } catch {}

    return $points
}