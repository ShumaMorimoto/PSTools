function Start-GenericPodeHost {
    param(
        [string]$Port = 8080,
        [string[]]$DllPaths = @(),      # 読み込むDLL
        [string[]]$ModulePaths = @(),   # 読み込むモジュール
        [hashtable]$ApiRoutes = @{},    # API定義 @{ "/url" = "Function-Name" }
        [string]$PublicPath = ""        # HTML置き場
    )

    # 1. DLLのロード
    foreach ($dll in $DllPaths) {
        $fullPath = Resolve-Path $dll -ErrorAction SilentlyContinue
        if ($fullPath) {
            try { Add-Type -Path $fullPath; Write-Host "DLL Loaded: $dll" -ForegroundColor Cyan }
            catch { Write-Warning "DLL Load Error: $dll" }
        }
    }

    # 2. モジュールのロード
    foreach ($mod in $ModulePaths) {
        $fullPath = Resolve-Path $mod -ErrorAction SilentlyContinue
        if ($fullPath) {
            try { Import-Module $fullPath -Force; Write-Host "Module Loaded: $mod" -ForegroundColor Cyan }
            catch { Write-Warning "Module Load Error: $mod" }
        }
    }

    Start-PodeServer {
        Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http

        # 静的ファイル設定
        if (-not [string]::IsNullOrEmpty($PublicPath) -and (Test-Path $PublicPath)) {
            Add-PodeStaticRoute -Path '/' -Source $PublicPath
        }

        # ==================== ログ強化部分 ====================

        if ($EnableDetailedLogging) {
            # 1. アクセスログ（全リクエストの基本情報）
            Enable-PodeAccessLogging -FilePath 'D:/logs/access.log'

            # 2. エラーログ（例外発生時）
            Enable-PodeErrorLogging -FilePath 'D:/logs/error.log' -IncludeStackTrace

            # 3. カスタムリクエストログミドルウェア（詳細情報）
            Add-PodeMiddleware -Name 'RequestLogger' -ScriptBlock {
                param($WebEvent)

                $startTime = Get-Date
                $requestId = [guid]::NewGuid().ToString().Substring(0, 8)
                $method = $WebEvent.Request.Method
                $path = $WebEvent.Request.Url.AbsolutePath
                $clientIp = $WebEvent.Request.RemoteEndPoint.Address

                # リクエストボディのログ（JSON想定、大きすぎる場合は制限）
                $body = $null
                if ($WebEvent.Data) {
                    try {
                        $body = $WebEvent.Data | ConvertTo-Json -Depth 3 -Compress
                        if ($body.Length -gt 1000) { $body = $body.Substring(0, 1000) + "..." }
                    }
                    catch { $body = "<非JSONまたは取得不可>" }
                }

                Write-Host "[REQ $requestId] $method $path from $clientIp" -ForegroundColor Yellow
                if ($body) { Write-Host "  Body: $body" -ForegroundColor DarkGray }

                # レスポンス後の処理（実行時間とステータスを記録）
                $WebEvent.OnEnd = {
                    $duration = ((Get-Date) - $startTime).TotalMilliseconds
                    $status = $WebEvent.Response.StatusCode
                    $route = $WebEvent.Route?.Path ?? $path

                    # どの関数が呼ばれたか（ConvertTo-PodeRouteの場合、Route.ScriptBlockから推定）
                    $calledFunction = "Unknown"
                    if ($WebEvent.Route?.ScriptBlock) {
                        $scriptText = $WebEvent.Route.ScriptBlock.ToString()
                        if ($scriptText -match 'Invoke-Command -ScriptBlock \{ & ([^\s]+)') {
                            $calledFunction = $matches[1]
                        }
                    }

                    Write-Host "[RES $requestId] $status $route ($calledFunction) - $($duration)ms" -ForegroundColor Cyan
                }

                return $true  # 次のミドルウェアへ進む
            }
        }

        # ==================== 動的ルート定義 ====================
        foreach ($entry in $ApiRoutes.GetEnumerator()) {
            $rPath = $entry.Key
            $rCmd = $entry.Value

            ConvertTo-PodeRoute -Path $rPath -Commands $rCmd -Method Get

            Write-Host "Route Mapped: POST $rPath -> $rCmd" -ForegroundColor Green
        }

        Add-PodeRoute -Method Post -Path "/api/gpx" -ScriptBlock {Get-Date}

    }
}

# 設定情報の定義
$config = @{
    Port      = 8080
    PublicPath  = Join-Path $PSScriptRoot "data"
    ModulePaths = @("D:\tool\Repository\PSTools\GenericHost\GPXTools\GPXTools.psm1")
    ApiRoutes = @{ "/api" = "Cluster-KMeans" }
}

# サーバー起動
Start-GenericPodeHost @config