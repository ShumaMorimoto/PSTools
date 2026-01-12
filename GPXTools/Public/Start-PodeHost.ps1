function Start-PodeHost {
    param(
        [int]$Port = 8080,
        [Parameter(Mandatory = $true)]
        [string]$ModuleName, 
        [string]$PublicPath = ""
    )

    $moduleRoot = Split-Path $PSScriptRoot -Parent
    
    # --- 1. 起動バナーの表示 ---
    Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
    Write-Host " Pode Host Environment Initializing " -ForegroundColor Black -BackgroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host "[Module Root] : $moduleRoot"
    Write-Host "[Port]        : $Port"

    $script:Pode_Port = $Port
    $psd1 = Join-Path $moduleRoot "$($ModuleName).psd1"
    $psm1 = Join-Path $moduleRoot "$($ModuleName).psm1"
    $script:Pode_ImportPath = if (Test-Path $psd1) { $psd1 } else { $psm1 }
    Write-Host "[Import Path] : $($script:Pode_ImportPath)" -ForegroundColor Gray

    $script:Pode_FinalPublic = if ([string]::IsNullOrWhiteSpace($PublicPath)) { Join-Path $moduleRoot "data" } else { $PublicPath }
    Write-Host "[Static Data] : $($script:Pode_FinalPublic)" -ForegroundColor Gray

    # routes.jsonの読み込み
    $routesFile = Join-Path $moduleRoot "routes.json"
    $script:Pode_Routes = @{}
    if (Test-Path $routesFile) {
        $json = Get-Content $routesFile -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $script:Pode_Routes[$prop.Name] = $prop.Value
        }
        Write-Host "[Routes Found]: $($script:Pode_Routes.Count) endpoints" -ForegroundColor Magenta
    }

    # --- 2. サーバー起動 ---
    Start-PodeServer {
        Add-PodeEndpoint -Address localhost -Port $script:Pode_Port -Protocol Http

        # 静的ルートのマッピング
        if ($script:Pode_FinalPublic -and (Test-Path $script:Pode_FinalPublic)) {
            Add-PodeStaticRoute -Path '/' -Source $script:Pode_FinalPublic
            Write-Host "Mapping Static: / -> $($script:Pode_FinalPublic)" -ForegroundColor DarkGray
        }

        $libPath = Join-Path (Split-Path $script:Pode_ImportPath -Parent) "lib"
        if (Test-Path $libPath) {
            Add-PodeStaticRoute -Path '/lib' -Source $libPath
            Write-Host "Mapping Static: /lib -> $libPath" -ForegroundColor DarkGray
        }

        # モジュールロード
        Import-Module $script:Pode_ImportPath -Force -Global
        Write-Host "Module '$ModuleName' loaded successfully." -ForegroundColor Green

        # 動的ルートの設定
        $routes = $script:Pode_Routes
        foreach ($entry in $routes.GetEnumerator()) {
            $rPath = $entry.Key
            $rCmd = $entry.Value

            $sb = {
                try {
                    $timestamp = Get-Date -Format "HH:mm:ss"
                    $data = $WebEvent.Data
                    
                    # --- 受信ログ ---
                    Write-Host "[$timestamp] [POST] $using:rPath -> Calling $using:rCmd" -ForegroundColor Cyan
                    if ($null -ne $data) {
                        $shortData = ($data | ConvertTo-Json -Compress)
                        if ($shortData.Length -gt 100) { $shortData = $shortData.Substring(0, 100) + "..." }
#                        Write-Host "      Payload: $shortData" -ForegroundColor DarkGray
                    }

                    # 関数実行
                    $result = & $using:rCmd -InputData $data
                    
                    # --- 正常終了ログ ---
#                   Write-Host "      Success: $($using:rCmd) execution completed." -ForegroundColor Green
                    Write-PodeJsonResponse -Value $result
                }
                catch {
                    # --- エラーログ ---
#                    Write-Host "[$timestamp] [ERROR] $using:rPath : $($_.Exception.Message)" -ForegroundColor Red
                    Write-PodeJsonResponse -Value @{
                        Success = $false
                        Error   = $_.Exception.Message
                    } -StatusCode 500
                }
            }
            Add-PodeRoute -Method Post -Path $rPath -ScriptBlock $sb
            Write-Host "Route Mapped: POST $rPath -> $rCmd" -ForegroundColor Cyan
        }

        Write-Host "`n--- Pode Server is Ready (localhost:$script:Pode_Port) ---`n" -ForegroundColor Yellow
    }
}