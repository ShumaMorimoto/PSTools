Start-PodeServer {
    # これを変更
#    Add-PodeEndpoint -Address 192.168.0.13 -Port $script:Pode_Port -Protocol Http
    # 例: Wi-FiのIPv4アドレスを自動で取る
    $lanIp = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Wireless*" }).IPAddress

    if ($lanIp) {
        Add-PodeEndpoint -Address $lanIp -Port $script:Pode_Port -Protocol Http
    }
    Add-PodeEndpoint -Address localhost -Port $script:Pode_Port -Protocol Http

    Add-PodeStaticRoute -Path '/' -Source "D:\tool\Repository\PSTools\開発中\SHM\data"

    # /api/location エンドポイントを追加（routes.jsonを使わず直接書いてもOK）
    Add-PodeRoute -Method Post -Path '/api/location' -ScriptBlock {
        try {
            $timestamp = Get-Date -Format "HH:mm:ss"
            $data = $WebEvent.Data   # ← スマホから送られたJSONがここに入る

            Write-Host "[$timestamp] POST /api/location received" -ForegroundColor Green
            Write-Host ($data | ConvertTo-Json -Depth 3) -ForegroundColor Cyan

            # ここで位置情報を保存・処理する例
            # $global:LatestLocation = $data
            # またはファイルに保存
            # $data | ConvertTo-Json | Out-File "C:\logs\locations.json" -Append

            Write-PodeJsonResponse -Value @{
                success  = $true
                message  = "Location received"
                received = $data
            }
        }
        catch {
            Write-PodeJsonResponse -Value @{
                success = $false
                error   = $_.Exception.Message
            } -StatusCode 500
        }
    }

    # 他のルートも必要なら...
}
