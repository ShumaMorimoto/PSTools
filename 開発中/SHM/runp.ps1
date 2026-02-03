# 必要モジュールがなければインストール（初回のみ）
# Install-Module -Name Pode -Scope CurrentUser -Force

$jsonPath = Join-Path "." "latest_location.json"

Start-PodeServer {

    # HTTPSで自己証明書（開発用）
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Https -SelfSigned

    # -----------------------------------------------------------------
    # 1. API：位置情報をアップロード（POST）
    # -----------------------------------------------------------------
    Add-PodeRoute -Method Post -Path '/api/location' -ScriptBlock {
        $body = $WebEvent.Data

        # 必要な値がちゃんとあるか簡易チェック
        if (-not $body.lat -or -not $body.lon) {
            Write-PodeJsonResponse -Value @{ 
                status = "error"
                message = "lat and lon are required"
            } -StatusCode 400
            return
        }

        $payload = [ordered]@{
            time     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            latitude  = [double]$body.lat
            longitude = [double]$body.lon
            # 必要に応じて追加可能
            # altitude  = [double]$body.alt
            # accuracy  = [int]$body.acc
            # source    = $body.source ?? "unknown"
        }

        # JSONとして上書き保存
        $payload | ConvertTo-Json -Depth 10 -Compress | 
            Out-File -FilePath $using:jsonPath -Encoding utf8 -Force

        Write-PodeJsonResponse -Value @{ 
            status  = "success"
            savedAt = $payload.time
        }
    }

    # -----------------------------------------------------------------
    # 2. API：最新の位置情報を取得（GET JSON）
    # -----------------------------------------------------------------
    Add-PodeRoute -Method Get -Path '/api/location' -ScriptBlock {
        if (Test-Path $using:jsonPath) {
            $content = Get-Content $using:jsonPath -Raw -Encoding utf8
            Write-PodeJsonResponse -Value $content
        }
        else {
            Write-PodeJsonResponse -Value @{ 
                status  = "error"
                message = "no location data yet"
            } -StatusCode 404
        }
    }

    # -----------------------------------------------------------------
    # 3. 簡易表示ページ（ブラウザで確認用）
    # -----------------------------------------------------------------
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $location = $null

        if (Test-Path $using:jsonPath) {
            try {
                $location = Get-Content $using:jsonPath -Raw | ConvertFrom-Json
            }
            catch { }
        }

        Write-PodeHtmlResponse @"
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>現在位置ダッシュボード</title>
  <style>
    body { font-family: system-ui, sans-serif; text-align:center; padding:2rem; background:#f8f9fa; }
    .card { max-width:480px; margin:0 auto; background:white; padding:2rem; border-radius:12px; box-shadow:0 4px 15px rgba(0,0,0,0.1); }
    h1 { color:#2c3e50; }
    .time { color:#7f8c8d; font-size:0.95em; }
    .coord { font-size:1.6em; font-weight:bold; margin:1.5em 0; }
    button { padding:0.8em 1.8em; font-size:1.1em; margin:0.5em; cursor:pointer; }
    #status { margin-top:1.5em; font-weight:bold; }
  </style>
</head>
<body>

<div class="card">
  <h1>現在の位置情報</h1>

  $(if ($location) {
    "<p class='time'>最終更新: $($location.time)</p>
     <div class='coord'>
       緯度: $($location.latitude)<br>
       経度: $($location.longitude)
     </div>"
  } else {
    "<p>まだ位置情報が登録されていません</p>"
  })

  <button onclick="sendLocation()">現在地を送信する</button>
  <button onclick="location.reload()">更新</button>

  <div id="status"></div>
</div>

<script>
async function sendLocation() {
  const status = document.getElementById("status");
  status.textContent = "取得中...";

  if (!navigator.geolocation) {
    status.textContent = "位置情報が利用できません";
    return;
  }

  navigator.geolocation.getCurrentPosition(
    async (pos) => {
      const data = {
        lat: pos.coords.latitude,
        lon: pos.coords.longitude,
        // alt: pos.coords.altitude,
        // acc: pos.coords.accuracy
      };

      try {
        const res = await fetch("/api/location", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(data)
        });

        if (res.ok) {
          status.textContent = "送信完了！";
          setTimeout(() => location.reload(), 1200);
        } else {
          status.textContent = "送信エラー: " + res.status;
        }
      } catch (err) {
        status.textContent = "通信エラー: " + err.message;
      }
    },
    (err) => {
      status.textContent = "位置情報の取得に失敗: " + err.message;
    },
    { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
  );
}
</script>

</body>
</html>
"@
    }

} -DisableTermination