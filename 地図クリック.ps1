#--------------------------------------
# PowerShell 7 で地図クリック座標を収集する
#--------------------------------------
param(
    [int]$Port = 5000
)

# 1) HTTP サーバ起動
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "📡 Listening on $prefix"

# クリック座標を格納する配列
$clickedCoords = [System.Collections.Generic.List[PSCustomObject]]::new()

# 返す HTML (Leaflet.js を使う)
$html = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Leaflet Map Click Demo</title>
  <style> #map { width: 100%; height: 80vh; } button {margin:10px;padding:5px 10px;} </style>
  <link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet/dist/leaflet.js"></script>
</head>
<body>
  <div id="map"></div>
  <button onclick="finish()">Finish</button>

  <script>
    // 地図初期化（東京駅近辺）
    var map = L.map('map').setView([35.681236, 139.767125], 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors'
    }).addTo(map);

    // クリックイベント
    map.on('click', function(e) {
      var coord = { lat: e.latlng.lat, lng: e.latlng.lng };
      console.log('Clicked:', coord);
      // PSサーバへ送信
      fetch('/click', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(coord)
      });
      // 地図にもマーカーを置く
      L.marker([coord.lat, coord.lng]).addTo(map);
    });

    // Finish ボタン押下
    function finish() {
      fetch('/done', { method: 'POST' })
        .then(function(){ alert('Done. You can close this window.'); });
    }
  </script>
</body>
</html>
"@

# 2) ブラウザで開く（非同期）
Start-Process "http://localhost:$Port/"

# 3) リクエスト処理ループ
$stopRequested = $false
while ($listener.IsListening -and -not $stopRequested) {
    $context = $listener.GetContext()
    $req = $context.Request
    $res = $context.Response

    try {
        if ($req.HttpMethod -eq 'GET' -and $req.Url.AbsolutePath -eq '/') {
            # HTML を返す
            $res.StatusCode  = 200
            $res.ContentType = 'text/html; charset=utf-8'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.Close()
        }
        elseif ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/click') {
            # クリック座標を受け取る
            $reader = [System.IO.StreamReader]::new($req.InputStream)
            $body   = $reader.ReadToEnd()
            $reader.Close()
            $data   = $body | ConvertFrom-Json
            # 格納
            $clickedCoords.Add([PSCustomObject]@{
                Lat = [double]$data.lat
                Lng = [double]$data.lng
                Time = (Get-Date).ToString("o")
            })
            Write-Host "▶ Clicked: $($data.lat), $($data.lng)"
            $res.StatusCode = 200
            $res.Close()
        }
        elseif ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/done') {
            # Finish 指示 => ループ終了フラグ
            Write-Host "🏁 Finish requested by browser."
            $stopRequested = $true
            $res.StatusCode = 200
            $res.Close()
        }
        else {
            # 未定義パスは 404
            $res.StatusCode = 404
            $res.Close()
        }
    }
    catch {
        Write-Warning "処理中に例外: $_"
        if ($res -and $res.OutputStream.CanWrite) {
            $res.StatusCode = 500
            $res.Close()
        }
    }
}

# 4) サーバ停止
$listener.Stop()
Write-Host "🛑 HTTP server stopped."

# 5) クリック座標一覧を表示／返す
Write-Host "`n===== Collected Coordinates ====="
$clickedCoords | Format-Table -AutoSize

# 必要があればこの配列を関数の返り値にしたり、
# CSV/JSON に書き出して別処理に渡すこともできます。
# 例：$clickedCoords | ConvertTo-Json | Out-File coords.json
