function Start-PodeHost {
    param(
        [int]$Port = 8080,
        [Parameter(Mandatory = $true)]
        [string]$ModuleName, 
        [string]$PublicPath = ""
    )

    $moduleRoot = Split-Path $PSScriptRoot -Parent
    
    # --- 1. 起動バナー ---
    Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
    Write-Host " Pode Host Environment Initializing " -ForegroundColor Black -BackgroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host "[Module Root] : $moduleRoot"
    Write-Host "[Port]        : $Port"

    $script:Pode_Port = $Port
    $psd1 = Join-Path $moduleRoot "$($ModuleName).psd1"
    $psm1 = Join-Path $moduleRoot "$($ModuleName).psm1"
    $script:Pode_ImportPath = if (Test-Path $psd1) { $psd1 } else { $psm1 }
    $script:Pode_FinalPublic = if ([string]::IsNullOrWhiteSpace($PublicPath)) { Join-Path $moduleRoot "data" } else { $PublicPath }

    # routes.jsonの読み込み
    $routesFile = Join-Path $moduleRoot "routes.json"
    $script:Pode_Routes = @{}
    if (Test-Path $routesFile) {
        $json = Get-Content $routesFile -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) { $script:Pode_Routes[$prop.Name] = $prop.Value }
    }

    # --- 2. サーバー起動 ---
    Start-PodeServer {
        Add-PodeEndpoint -Address localhost -Port $script:Pode_Port -Protocol Http

        if ($script:Pode_FinalPublic -and (Test-Path $script:Pode_FinalPublic)) {
            Add-PodeStaticRoute -Path '/' -Source $script:Pode_FinalPublic
        }

        $libPath = Join-Path (Split-Path $script:Pode_ImportPath -Parent) "lib"
        if (Test-Path $libPath) {
            Add-PodeStaticRoute -Path '/lib' -Source $libPath
        }

        Import-Module $script:Pode_ImportPath -Force -Global
        Write-Host "Module '$ModuleName' loaded." -ForegroundColor Green

        $routes = $script:Pode_Routes
        foreach ($entry in $routes.GetEnumerator()) {
            $rPath = $entry.Key
            $rCmd = $entry.Value

            $sb = {
                try {
                    $timestamp = Get-Date -Format "HH:mm:ss"
                    $data = $WebEvent.Data
                    
                    Write-Host "[$timestamp] [POST] $using:rPath -> $using:rCmd" -ForegroundColor Cyan
                    
                    # 1. 関数実行
                    $result = & $using:rCmd -InputData $data
                    
                    Write-PodeJsonResponse -Value $result
                }
                catch {
                    # エラー時は通常のオブジェクトで返す
                    Write-PodeJsonResponse -Value @{
                        Success = $false
                        Error   = $_.Exception.Message
                    } -StatusCode 500
                }
            }
            Add-PodeRoute -Method Post -Path $rPath -ScriptBlock $sb
            Write-Host "Route Mapped: POST $rPath" -ForegroundColor Cyan
        }
    }
}