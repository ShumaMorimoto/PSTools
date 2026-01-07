function Start-MyApp {
    # 1. パスの特定と設定の読み込み
    $moduleRoot = $PSScriptRoot 
    $configPath = Join-Path $moduleRoot "conf/server-config.json"
    
    if (-not (Test-Path $configPath)) {
        Write-Error "Config file not found: $configPath"
        return
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $staticFilesPath = Join-Path $moduleRoot "data"
    $url = "http://localhost:$($config.Server.Port)"

    # --- 状態管理オブジェクトの初期化 ---
    $GlobalState = @{
        Phase     = "Idle"
        UpdatedAt = (Get-Date)
        Result    = $null
    }

    Write-Host "Starting App at $url" -ForegroundColor Cyan

    # 2. サーバー起動
    Start-PodeServer {
        Add-PodeEndpoint -Address * -Port $config.Server.Port -Protocol Http

        # A. 開発対象 (dataフォルダ) をルート '/' として公開
        Add-PodeStaticRoute -Path '/' -Source $staticFilesPath -DefaultFile $config.Server.DefaultFile

        # B. ライブラリ (libフォルダ) を '/lib' として公開
        $libPath = Join-Path $moduleRoot "lib"
        Add-PodeStaticRoute -Path '/lib' -Source $libPathFilesPath -DefaultFile $config.Server.DefaultFile

        # =======================================================
        # システム標準ルート（固定定義）
        # =======================================================
        
        # --- 状態取得 (State取得専用: コマンド定義不要) ---
        Add-PodeRoute -Method POST -Path '/api/status' -ScriptBlock {
            # 常に最新の $GlobalState をそのまま返却
            Write-PodeJsonResponse -Value $using:GlobalState
        }

        # --- シャットダウン用 ---
        Add-PodeRoute -Method POST -Path '/shutdown' -ScriptBlock {
            Write-Host "Shutdown request received. Stopping server..." -ForegroundColor Red
            Write-PodeJsonResponse -Value @{ status = "terminating"; message = "Server is shutting down." }
            Start-Sleep -Seconds 1
            Stop-PodeServer
        }

        # =======================================================
        # 3. 動的ルート登録 (API Mappings)
        # =======================================================
        foreach ($mapping in $config.ApiMappings) {
            $cmdName = $mapping.Command
            $path = $mapping.Path
            $method = $mapping.Method

            if (Get-Command $cmdName -ErrorAction SilentlyContinue) {
                Add-PodeRoute -Method $method -Path $path -ScriptBlock {
                    try {
                        # 共通の $GlobalState を引数としてコマンドに注入
                        $res = & $using:cmdName -Data $WebEvent.Data -State $using:GlobalState
                        Write-PodeJsonResponse -Value $res
                    }
                    catch {
                        Write-PodeJsonResponse -Value @{ error = $_.Exception.Message } -StatusCode 500
                    }
                }
            }
            else {
                Write-PodeLog -Message "Warning: Command [$cmdName] not found."
            }
        }

        # --- ブラウザの自動起動 ---
        Write-Host "Opening browser..." -ForegroundColor Green
        Start-Process $url
    }
}

# 外部公開用
Export-ModuleMember -Function Start-MyApp