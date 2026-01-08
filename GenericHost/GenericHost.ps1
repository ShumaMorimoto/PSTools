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
        foreach ($entry in $ApiRoutes.GetEnumerator()) {
            $path = $entry.Key
            $cmdName = $entry.Value # 例: "Cluster-KMeans"

            # 実行するスクリプトブロックを「文字列」として組み立てる
            # $cmdName を直接コードの中に書き込むのがコツです
            $routeCode = @"
                try {
                    `$data = `$WebEvent.Data
                    # 直接コマンド名を書き込み済み
                    `$result = $cmdName @data

                    Write-PodeJsonResponse -Value @{
                        Success = `$true
                        Data    = `$result
                    }
                }
                catch {
                    Write-PodeJsonResponse -Value @{
                        Success = `$false
                        Error   = `$_.Exception.Message
                    } -StatusCode 500
                }
"@
            # 文字列からスクリプトブロックを生成
            $sb = [scriptblock]::Create($routeCode)

            # ルート登録
            Add-PodeRoute -Method Post -Path $path -ScriptBlock $sb
            
            Write-Host "Route Mapped: POST $path -> $cmdName" -ForegroundColor Green
        }

            ConvertTo-PodeRoute -Path '/api' -Commands @('Cluster-KMeans') -Method Post
    }
}

# --- 設定 ---
$config = @{
    Port        = 8080
    PublicPath  = Join-Path $PSScriptRoot "data"
    ModulePaths = @( Join-Path $PSScriptRoot "GPXTools\GPXTools.psm1" )
    ApiRoutes   = @{ "/api/gpx" = "Cluster-KMeans" }
}

# 実行
Start-GenericPodeHost @config