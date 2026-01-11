Import-Module Pode

function Start-GenericPodeHost {
    param(
        [int]$Port = 8080,
        [string[]]$DllPaths = @(),
        [string[]]$ModulePaths = @(),
        [hashtable]$ApiRoutes = @{},
        [string]$PublicPath = ""
    )

    # サーバーの起動
    Start-PodeServer {
        # エンドポイント
        Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http

        # 静的ファイル設定
        if ($PublicPath -and (Test-Path $PublicPath)) {
            Add-PodeStaticRoute -Path '/' -Source $PublicPath
        }

        # サーバー起動時にDLLとモジュールをロード
        # (Start-PodeServer の直下で実行)
        foreach ($dll in $DllPaths) { Add-Type -Path $dll }
        foreach ($mod in $ModulePaths) { Import-Module $mod -Force }

        # 動的ルート定義
        # 動的ルート定義部分を置き換え
        # 動的ルート定義部分を置き換え
        foreach ($entry in $ApiRoutes.GetEnumerator()) {
            $rPath = $entry.Key
            $rCmd = $entry.Value

            # 共通のスクリプトブロックテンプレート（文字列不要）
            $sb = {
                try {
                    $data = $WebEvent.Data

                    # $using:でループ時の値をキャプチャ
                    $result = & $using:rCmd @data
                    Write-PodeJsonResponse -Value $result

                }
                catch {
                    Write-PodeJsonResponse -Value @{
                        Success = $false
                        Error   = $_.Exception.Message
                    } -StatusCode 500
                }
            }

            Add-PodeRoute -Method Post -Path $rPath -ScriptBlock $sb
            Write-Host "Route Mapped: POST $rPath -> $rCmd" -ForegroundColor Green
        }
    }
}

# --- 設定 ---
$config = @{
    Port        = 8080
    PublicPath  = "D:\tool\Repository\PSTools\開発中\GPX7"
    ModulePaths = @( "D:\tool\Repository\PSTools\GPXTools\GPXTools.psm1" )
    ApiRoutes   = @{ "/api/TSPSolver" = "Invoke-TSPSolver";"/api/KMeansCluster" = "Invoke-KMeansCluster"
    }
}

# 実行
Start-GenericPodeHost @config