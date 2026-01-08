Import-Module Pode

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

    # 3. サーバー起動
    Start-PodeServer {
        Add-PodeEndpoint -Address * -Port $Port -Protocol Http

        # 静的ファイル設定
        if (-not [string]::IsNullOrEmpty($PublicPath) -and (Test-Path $PublicPath)) {
            Add-PodeStaticRoute -Path '/' -Source $PublicPath
        }

        # 4. 動的ルート定義
        # ループ変数のスコープ問題を回避するため、[scriptblock]::Create でコードを焼き込みます
        foreach ($entry in $ApiRoutes.GetEnumerator()) {
            $rPath = $entry.Key   # 例: /api/gpx
            $rCmd = $entry.Value # 例: Invoke-GpxCity

            # 文字列としてスクリプトブロックを生成
            # JSONデータ($WebEvent.Data)を、そのまま関数の引数(＠data)として渡します(Splatting)
            $sbCode = @"
                try {
                    `$data = `$WebEvent.Data
                    
                    # 例: { "cityName": "葉山" } -> Invoke-GpxCity -cityName "葉山"
                    `$result = $rCmd @data

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
            $sb = [scriptblock]::Create($sbCode)

            # POSTメソッドとして登録
            Add-PodeRoute -Method Post -Path $rPath -ScriptBlock $sb
            Write-Host "Route Mapped: POST $rPath -> $rCmd" -ForegroundColor Green
        }
    }
}

# 1. 汎用ホスト関数の読み込み
# . "$PSScriptRoot\GenericPodeHost.ps1"

# 2. 設定情報の定義
$config = @{
    Port        = 8080
    PublicPath  = Join-Path $PSScriptRoot "public"

    # 読み込むDLLがあれば指定
    # DllPaths    = @( Join-Path $PSScriptRoot "MyLib.dll" )

    # 自作モジュールを指定
    ModulePaths = @(
        "GPXTools"
    )

    # APIのマッピング
    # POSTリクエストのURLパス = 実行する関数名
    ApiRoutes   = @{
        "/api/gpx" = "Cluster-KMeans"
    }
}

# 3. サーバー起動
Start-GenericPodeHost @config



