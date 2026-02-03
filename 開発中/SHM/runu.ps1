$jsonPath = Join-Path (Get-Location) "latest_location.json"

Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Https -SelfSigned

    # API: 送信されたデータを保存
    Add-PodeRoute -Method Post -Path '/api/location' -ScriptBlock {
        $body = $WebEvent.Data
        $payload = @{
            time = Get-Date -Format "HH:mm:ss"
            latitude  = $body.lat
            longitude = $body.lon
        }
        $payload | ConvertTo-Json | Out-File -FilePath $using:jsonPath -Encoding utf8 -Force
        Write-PodeJsonResponse -Value @{ status = "auto_updated" }
    }

    # 画面: アクセス時に自動で位置取得・送信を実行
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeHtmlResponse -Value @"
        <html>
        <head><meta charset="UTF-8"></head>
        <body style="background:#000; color:#0f0; font-family:monospace; text-align:center; padding-top:50px;">
            <div id="status">CONNECTING...</div>
            <script>
                const status = document.getElementById('status');

                // ページ読み込み時に実行
                window.onload = () => {
                    if (!navigator.geolocation) {
                        status.innerText = "NOT SUPPORTED";
                        return;
                    }

                    // 位置情報の監視（移動しても自動更新される）
                    navigator.geolocation.watchPosition(async p => {
                        const data = { lat: p.coords.latitude, lon: p.coords.longitude };
                        status.innerText = "SENDING: " + data.lat + ", " + data.lon;

                        try {
                            await fetch('/api/location', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify(data)
                            });
                            status.innerText = "LAST UPDATED: " + new Date().toLocaleTimeString();
                        } catch (e) {
                            status.innerText = "ERROR";
                        }
                    }, e => {
                        status.innerText = "PERMISSION DENIED OR ERROR";
                    }, { enableHighAccuracy: true });
                };
            </script>
        </body>
        </html>
"@
    }
} -DisableTermination