param(
  [string]$CenterKeyword,      # 住所や地名で中心を指定したい場合
  [double]$CenterLat,          # 緯度を直接指定したい場合
  [double]$CenterLng,          # 経度を直接指定
  [int]$Zoom = 13,
  [int]$Port = 5000,
  [string]$GpxPath = "selected_points.gpx"
)

# 1) キーワード→緯度経度 もしくは 直接指定
if (-not ($CenterLat -and $CenterLng)) {
  if (-not $CenterKeyword) {
    throw "CenterKeyword か CenterLat+CenterLng のいずれかを指定してください。"
  }
  Write-Host "ジオコーディング: $CenterKeyword"
  $url = "https://nominatim.openstreetmap.org/search?format=json&q=$([uri]::EscapeDataString($CenterKeyword))"
  $res = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = 'PSMapDemo' }
  if (!$res) { throw "見つかりませんでした: $CenterKeyword" }
  $CenterLat = [double]$res[0].lat
  $CenterLng = [double]$res[0].lon
  Write-Host "→ 中心地点: $CenterLat, $CenterLng"
}

# 2) HTTP サーバ立ち上げ
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "地図サーバ起動: $prefix"

# クリック座標のリスト
$points = [System.Collections.Generic.List[PSCustomObject]]::new()

# HTML + JavaScript（Leaflet）
$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Map Point Selector</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css" />
<script src="https://unpkg.com/leaflet/dist/leaflet.js"></script>
<style> body, html { margin:0; padding:0; height:100%; } #map { width:100%; height:90%; } button { width:100%; height:10%; font-size:1.2em; } </style>
</head>
<body>
<div id="map"></div>
<button onclick="finish()">Finish and Exit</button>
<script>
  var map = L.map('map').setView([$CenterLat, $CenterLng], $Zoom);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    { attribution: '© OpenStreetMap contributors' }
  ).addTo(map);

  map.on('click', function(e) {
    var coord = { lat: e.latlng.lat, lng: e.latlng.lng };
    L.marker([coord.lat, coord.lng]).addTo(map);
    fetch('/click', {
      method:'POST',
      headers:{ 'Content-Type':'application/json' },
      body: JSON.stringify(coord)
    });
  });

  function finish() {
    fetch('/done',{ method:'POST' })
      .then(()=>{ alert("Done. Close this window."); });
  }
</script>
</body>
</html>
"@

# ブラウザで開く
Start-Process $prefix

# 3) リッスンループ
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
    $body = (New-Object IO.StreamReader $req.InputStream).ReadToEnd()
    $data = $body | ConvertFrom-Json
    $points.Add([PSCustomObject]@{
      Lat = [double]$data.lat
      Lng = [double]$data.lng
      Time = (Get-Date).ToString("o")
    })
    Write-Host "選択: $($data.lat), $($data.lng)"
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

$listener.Stop()
Write-Host "サーバ停止。選択点を GPX に変換します…"

# 4) GPX ファイル生成
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

  $wpts = foreach ($i=0; $i -lt $Items.Count; $i++) {
    $pt = $Items[$i]
    $idx = $i+1
    @"
  <wpt lat="$($pt.Lat)" lon="$($pt.Lng)">
    <name>Point$idx</name>
    <time>$($pt.Time)</time>
  </wpt>
"@
  }

  $footer = "</gpx>"

  $all = $header + ($wpts -join "`n") + "`n" + $footer
  [IO.File]::WriteAllText($OutPath, $all, [Text.Encoding]::UTF8)
  Write-Host "GPX 保存完了： $OutPath"
}

Convert-ToGpx -Items $points -OutPath $GpxPath

# 完了
Write-Host "`n処理完了。選択された座標一覧："
$points | Format-Table -AutoSize
