$clientId = "182418997846-ui3m0v9jqjr1e3gd986cqu1b7e46o4ha.apps.googleusercontent.com"
$scope = "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive"
$redirectUri =  "http://127.0.0.1:80/" # デスクトップアプリ用

$authUrl = "https://accounts.google.com/o/oauth2/v2/auth?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&scope=$scope&access_type=offline"

Start-Process $authUrl  # ブラウザで開く

# ローカルHTTPリスナーを開始
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($redirectUri)
$listener.Start()
Write-Host "Waiting for Google OAuth response..."

# リクエストを受信
$context = $listener.GetContext()
$code = $context.Request.QueryString["code"]

# レスポンスを返してブラウザを閉じる
$response = $context.Response
$responseString = "<html><body><h1>認証完了。ウィンドウを閉じてください。</h1></body></html>"
$buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
$response.ContentLength64 = $buffer.Length
$response.OutputStream.Write($buffer, 0, $buffer.Length)
$response.OutputStream.Close()
$listener.Stop()

Write-Host "認証コード取得: $code"

# トークン取得
$tokenResponse = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method POST -Body @{
    code = $code
    client_id = $clientId
    client_secret = $clientSecret
    redirect_uri = $redirectUri
    grant_type = "authorization_code"
}

$accessToken = $tokenResponse.access_token
$refreshToken = $tokenResponse.refresh_token

Write-Host "Access Token: $accessToken"
Write-Host "Refresh Token: $refreshToken"
