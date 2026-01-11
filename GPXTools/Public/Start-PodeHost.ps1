function Start-PodeHost {
    param(
        [int]$Port = 8080,
        [Parameter(Mandatory = $true)]
        [string]$ModuleName, 
        [string]$PublicPath = ""
    )

    # 1. 関数ファイル (Start-PodeHost.ps1) がある場所からルートを特定
    # $PSScriptRoot は実行中のスクリプトファイルの親ディレクトリを指す
    $moduleRoot = Split-Path $PSScriptRoot -Parent # Public の親

    # デバッグ用にパスを表示（不要になったら消してください）
    Write-Host "Searching for module at: $moduleRoot" -ForegroundColor Gray

    # 2. 変数のセット
    $script:Pode_Port = $Port
    
    # 拡張子を確認してインポートパスを確定
    $psd1 = Join-Path $moduleRoot "$($ModuleName).psd1"
    $psm1 = Join-Path $moduleRoot "$($ModuleName).psm1"
    $script:Pode_ImportPath = if (Test-Path $psd1) { $psd1 } else { $psm1 }

    $script:Pode_FinalPublic = if ([string]::IsNullOrWhiteSpace($PublicPath)) {
        Join-Path $moduleRoot "data"
    }
    else {
        $PublicPath
    }

    # 3. routes.jsonの読み込み
    $routesFile = Join-Path $moduleRoot "routes.json"
    $script:Pode_Routes = @{}
    if (Test-Path $routesFile) {
        $json = Get-Content $routesFile -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $script:Pode_Routes[$prop.Name] = $prop.Value
        }
    }

    # 4. サーバー起動
    Start-PodeServer {
        Add-PodeEndpoint -Address localhost -Port $script:Pode_Port -Protocol Http

        if ($script:Pode_FinalPublic -and (Test-Path $script:Pode_FinalPublic)) {
            Add-PodeStaticRoute -Path '/' -Source $script:Pode_FinalPublic
        }

        $libPath = Join-Path (Split-Path $script:Pode_ImportPath -Parent) "lib"
        if (Test-Path $libPath) {
            Add-PodeStaticRoute -Path '/lib' -Source $libPath
            Write-Host "Static Route Mapped: /lib -> $libPath" -ForegroundColor Cyan
        }

        # モジュールをフルパスでロード
        Import-Module $script:Pode_ImportPath -Force -Global

        $routes = $script:Pode_Routes
        foreach ($entry in $routes.GetEnumerator()) {
            $rPath = $entry.Key
            $rCmd = $entry.Value

            $sb = {
                try {
                    $data = $WebEvent.Data
                    $result = & $using:rCmd -InputData $data
                   # $result = & $using:rCmd @data
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