Import-Module Pode

function Start-PodeHost {
    param(
        [int]$Port = 8080,
        [Parameter(Mandatory=$true)]
        [string]$ModuleName,
        [string]$PublicPath = ""
    )

    # 1. サーバーの外で変数を「スクリプトスコープ」にセットする
    # これにより、Start-PodeServer 内部から直接参照できるようになります
    $script:Pode_Port = $Port
    $script:Pode_Module = $ModuleName
    $script:Pode_Public = $PublicPath

    # モジュールのルート特定とJSON読み込み
    $mod = Get-Module -ListAvailable $ModuleName | Select-Object -First 1
    $moduleRoot = if ($mod) { $mod.ModuleBase } else { Split-Path $ModuleName }
    $routesFile = Join-Path $moduleRoot "routes.json"
    
    $script:Pode_Routes = @{}
    if (Test-Path $routesFile) {
        $json = Get-Content $routesFile -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $script:Pode_Routes[$prop.Name] = $prop.Value
        }
    }

    $script:Pode_FinalPublic = if ([string]::IsNullOrWhiteSpace($PublicPath)) {
        Join-Path $moduleRoot "data"
    } else {
        $PublicPath
    }

    # 2. サーバー起動（実績のあるコードの中身を維持）
    Start-PodeServer {
        # $script: スコープ経由で変数を参照
        Add-PodeEndpoint -Address localhost -Port $script:Pode_Port -Protocol Http

        if ($script:Pode_FinalPublic -and (Test-Path $script:Pode_FinalPublic)) {
            Add-PodeStaticRoute -Path '/' -Source $script:Pode_FinalPublic
        }

        # モジュールのロード
        Import-Module $script:Pode_Module -Force

        # 動的ルート定義（実績のあるループ処理をそのまま使用）
        foreach ($entry in $script:Pode_Routes.GetEnumerator()) {
            $rPath = $entry.Key
            $rCmd = $entry.Value

            # 実績のあるスクリプトブロック構造
            $sb = {
                try {
                    $data = $WebEvent.Data
                    # ここは Pode の仕様通り $using:rCmd で現在のループの値をキャプチャ
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

# 実行
Start-PodeHost -ModuleName "D:\tool\Repository\PSTools\GPXTools\GPXTools.psm1" `
               -PublicPath "D:\tool\Repository\PSTools\開発中\GPX7"