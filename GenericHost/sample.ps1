# Podeがなければインストール
if (-not (Get-Module -ListAvailable -Name Pode)) {
    Install-Module Pode -Scope CurrentUser -Force
}

Start-PodeServer {
    # HTTP 8080ポートで待機
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # 静的ファイルのルート（publicフォルダを作成してそこにHTMLを置く）
    # スクリ, publicフォルダがなければ作成
    $publicPath = Join-Path $PSScriptRoot "public"
    if (-not (Test-Path $publicPath)) {
        New-Item -ItemType Directory -Path $publicPath | Out-Null
    }
    Add-PodeStaticRoute -Path '/' -Source $publicPath

    # === POSTテスト用API ===
    Add-PodeRoute -Method Post -Path '/api/test2' -ScriptBlock {
        $body = $WebEvent.Data   # 送信されたJSONまたはフォームデータ

        Write-PodeJsonResponse -Value @{
            Success       = $true
            Message       = "POST成功！サーバーがデータを正しく受け取りました"
            ReceivedData  = $body
            ServerTime    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ContentLength = $WebEvent.Request.ContentLength64
        }
    }

    # === POSTテスト用API ===
    ConvertTo-PodeRoute -Path '/api/test' -Commands @('Get-Date') -Method Get

    ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Invoke-Expression')

    # === 生きてるか確認用 ===
    Add-PodeRoute -Method Get -Path '/ping' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Status = "OK"
            Time   = Get-Date
        }
    }
}

# サーバー起動後に自動でHTMLファイルを作成
$publicPath = Join-Path $PSScriptRoot "public"
if (-not (Test-Path $publicPath)) { New-Item -ItemType Directory -Path $publicPath | Out-Null }

$htmlContent = @'
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pode POST テストページ</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; background: #f4f4f4; }
        h1 { color: #333; }
        .form-group { margin: 20px 0; }
        label { display: block; margin-bottom: 8px; font-weight: bold; }
        input, textarea { width: 100%; padding: 10px; font-size: 16px; }
        button { padding: 12px 24px; font-size: 18px; background: #007bff; color: white; border: none; cursor: pointer; }
        button:hover { background: #0056b3; }
        #result { margin-top: 30px; padding: 15px; background: white; border: 1px solid #ddd; white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>Pode POST テストページ</h1>
    <p>このフォームからPOSTリクエストを送信して、サーバーの応答を確認できます。</p>

    <div class="form-group">
        <label for="name">名前</label>
        <input type="text" id="name" value="修馬">
    </div>

    <div class="form-group">
        <label for="city">都市</label>
        <input type="text" id="city" value="横須賀">
    </div>

    <div class="form-group">
        <label for="message">メッセージ</label>
        <textarea id="message" rows="4">こんにちは！これはテストです。</textarea>
    </div>

    <button onclick="sendPost()">POST送信</button>

    <h2>サーバーからの応答：</h2>
    <div id="result" style="background:#eee;">まだ送信していません...</div>

    <script>
        async function sendPost() {
            const data = {
                name: document.getElementById('name').value,
                city: document.getElementById('city').value,
                message: document.getElementById('message').value
            };

            try {
                const response = await fetch('/api/test', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });

                const result = await response.json();
                document.getElementById('result').textContent = JSON.stringify(result, null, 2);
            } catch (err) {
                document.getElementById('result').textContent = 'エラー: ' + err.message;
            }
        }
    </script>
</body>
</html>
'@

# index.html を自動作成
$htmlPath = Join-Path $publicPath "index.html"
$htmlContent | Out-File -FilePath $htmlPath -Encoding utf8
Write-Host "POSTテストページを作成しました: $htmlPath" -ForegroundColor Green
Write-Host "ブラウザで開いてください → http://localhost:8080/" -ForegroundColor Yellow