param(
    [string]$CenterKeyword,      # 住所／地名指定（例: "東京駅"）
    [double]$CenterLat,          # 緯度を直接指定する場合
    [double]$CenterLng,          # 経度を直接指定する場合
    [int]$Zoom = 13,
    [int]$Port = 5000,
    [string]$GpxPath = "selected_points.gpx"
)

# --- 1) 中心座標取得（キーワード or 直接指定） ---
if (-not ($CenterLat -and $CenterLng)) {
    if (-not $CenterKeyword) {
        Write-Host "CenterKeyword または CenterLat と CenterLng のいずれかを指定してください。"
        return
    }
    Write-Host "ジオコーディング: $CenterKeyword"
    $q = [uri]::EscapeDataString($CenterKeyword)
    $url = "https://nominatim.openstreetmap.org/search?format=json&q=$q"
    try {
        $res = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = 'PS-MapSelector/1.0' } -UseBasicParsing
    }
    catch {
        Write-Error "ジオコーディングに失敗しました: $_"
        return
    }
    if (-not $res -or $res.Count -eq 0) {
        Write-Error "ジオコーディングで結果が見つかりませんでした。"
        return
    }
    $CenterLat = [double]$res[0].lat
    $CenterLng = [double]$res[0].lon
    Write-Host "→ 中心: $CenterLat, $CenterLng"
}

# --- 2) 簡易 HTTP サーバの準備 ---
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
}
catch {
    Write-Error "ポート $Port でリスンできません： $_"
    return
}
Write-Host "地図サーバ起動: $prefix"

# クリック座標リスト
$points = [System.Collections.Generic.List[PSCustomObject]]::new()

# HTML + JS（Leaflet）
$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Map Point Selector</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css" />
<script src="https://unpkg.com/leaflet/dist/leaflet.js"></script>
<style>
  html,body { height:100%; margin:0; padding:0; }
  #map { width:100%; height:88%; }
  #controls { height:12%; padding:8px; box-sizing:border-box; display:flex; gap:8px; }
  input[type=text] { flex:1; padding:6px; font-size:1rem; }
  button { padding:6px 12px; font-size:1rem; }
</style>
</head>
<body>
<div id="map"></div>
<div id="controls">
  <input id="searchBox" type="text" placeholder="地名や住所で検索 (例: 京都駅)" />
  <button onclick="search()">Search</button>
  <button onclick="clearMarkers()">Clear Markers</button>
  <button onclick="finish()">Finish</button>
</div>

<script>
  var map = L.map('map').setView([$CenterLat, $CenterLng], $Zoom);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap contributors' }).addTo(map);

  var markers = [];

  map.on('click', function(e) {
    var coord = { lat: e.latlng.lat, lng: e.latlng.lng };
    addMarker(coord.lat, coord.lng);
    // PowerShellサーバへ送信
    fetch('/click', {
      method:'POST',
      headers:{ 'Content-Type':'application/json' },
      body: JSON.stringify(coord)
    });
  });

  function addMarker(lat,lng) {
    var m = L.marker([lat,lng]).addTo(map);
    markers.push(m);
  }

  function clearMarkers(){
    markers.forEach(function(m){ map.removeLayer(m); });
    markers = [];
    // PowerShell側で記録をクリアしたければ API 追加可（今回はローカルのみ）
  }

  function finish(){
    fetch('/done',{ method:'POST' })
      .then(function(){ alert('Finish requested. You can close this window.'); });
  }

  // 簡易検索（Nominatim を利用）。利用規約に注意。User-Agent が必要。
  function search(){
    var q = document.getElementById('searchBox').value;
    if(!q) { alert('検索語を入力してください'); return; }
    var url = 'https://nominatim.openstreetmap.org/search?format=json&q=' + encodeURIComponent(q);
    fetch(url, { headers: { 'User-Agent': 'PS-MapSelector/1.0' } })
      .then(r=>r.json())
      .then(data=>{
        if(!data || data.length==0){ alert('見つかりません'); return; }
        var lat = parseFloat(data[0].lat), lon = parseFloat(data[0].lon);
        map.setView([lat, lon], 15);
      })
      .catch(e=>{ alert('検索エラー'); console.log(e); });
  }
</script>
</body>
</html>
"@

# ブラウザで開く
Start-Process $prefix

# --- 3) リッスンループ ---
$stop = $false
while (-not $stop) {
    try {
        $ctx = $listener.GetContext()
    }
    catch {
        break
    }
    $req = $ctx.Request; $res = $ctx.Response
    try {
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
                        Lat  = [double]$data.lat
                        Lng  = [double]$data.lng
                        Time = (Get-Date).ToString("o")
                    })
                Write-Host "Selected: $($data.lat), $($data.lng)"
            }
            $res.StatusCode = 200; $res.Close()
        }
        elseif ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/done') {
            Write-Host "Finish requested from browser."
            $stop = $true
            $res.StatusCode = 200; $res.Close()
        }
        else {
            $res.StatusCode = 404; $res.Close()
        }
    }
    catch {
        Write-Warning "Request handling error: $_"
        if ($res -and $res.OutputStream.CanWrite) { $res.StatusCode = 500; $res.Close() }
    }
}

# --- 4) サーバ停止 ---
try { $listener.Stop() } catch {}
Write-Host "サーバ停止。選択点を GPX に変換します…"

# --- 5) GPX 生成関数（for を使用） ---
function Convert-ToGpx {
    param($Items, $OutPath)

    $header = @"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<gpx version="1.1" creator="PS-MapSelector"
 xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>Selected Points</name>
    <time>$(Get-Date -Format o)</time>
  </metadata>
"@

    $wpts = for ($i = 0; $i -lt $Items.Count; $i++) {
        $pt = $Items[$i]
        $idx = $i + 1
        @"
  <wpt lat="$($pt.Lat)" lon="$($pt.Lng)">
    <name>Point$idx</name>
    <time>$($pt.Time)</time>
  </wpt>
"@
    }

    $footer = "</gpx>"

    $content = $header + ($wpts -join "`n") + "`n" + $footer
    try {
        [IO.File]::WriteAllText($OutPath, $content, [Text.Encoding]::UTF8)
        Write-Host "GPX saved: $OutPath"
    }
    catch {
        Write-Error "GPX書き込みエラー: $_"
    }
}

Convert-ToGpx -Items $points -OutPath $GpxPath

Write-Host "`n完了。選択された点："
$points | Format-Table -AutoSize
