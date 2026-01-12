function Invoke-SampleProcess {
    param($Data, $State)
    $State.Phase = "Running..."
    Start-Sleep -Seconds 2
    $State.Phase = "Idle"
    return @{ message = "Success!"; received = $Data.input }
}

function Start-MyApp {
    # 1. パラメーター準備
    $appParams = @{
        ModuleRoot  = $PSScriptRoot
        Config      = Get-Content (Join-Path $PSScriptRoot "conf/server-config.json") -Raw | ConvertFrom-Json
        GlobalState = @{ Phase = "Idle"; UpdatedAt = (Get-Date) }
    }

    # 2. グローバル変数に一時保存（どんなPodeバージョンでも確実）
    $global:PodeAppParams = $appParams

    # 3. Start-PodeServer（$using: も -ArgumentList も一切使わない）
    Start-PodeServer {
        # グローバルから取り出してPodeStateにセット
        $params = $global:PodeAppParams
        Remove-Variable -Name PodeAppParams -Scope Global -ErrorAction SilentlyContinue  # 後片付け

        Set-PodeState -Name 'ModuleRoot'  -Value $params.ModuleRoot
        Set-PodeState -Name 'AppConfig'   -Value $params.Config
        Set-PodeState -Name 'SharedState' -Value $params.GlobalState

        $conf = $params.Config
        $root = $params.ModuleRoot

        Add-PodeEndpoint -Address * -Port $conf.Server.Port -Protocol Http
        
        Add-PodeStaticRoute -Path '/lib' -Source (Join-Path $root "lib")
        Add-PodeStaticRoute -Path '/'   -Source (Join-Path $root "data")

        # ルート('/') で index.html を明示的に返す（静的ルートのフォールバック）
        Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
            $rootPath = Get-PodeState -Name 'ModuleRoot'
            Write-PodeFileResponse -Path (Join-Path $rootPath "data/index.html")
        }

        Add-PodeRoute -Method POST -Path '/api/status' -ScriptBlock {
            Write-PodeJsonResponse -Value (Get-PodeState -Name 'SharedState')
        }

        Add-PodeRoute -Method POST -Path '/shutdown' -ScriptBlock { 
            Write-PodeJsonResponse -Value @{ status = "ok" }
            Start-Sleep -Seconds 1
            Stop-PodeServer 
        }

        # 動的API登録（クロージャ対策済み）
        foreach ($mapping in $conf.ApiMappings) {
            $cmdName = $mapping.Command  # ローカルコピー

            Add-PodeRoute -Method $mapping.Method -Path $mapping.Path -ArgumentList $cmdName -ScriptBlock {
                param($cmdName)
                try {
                    $state = Get-PodeState -Name 'SharedState'
                    $res = & $cmdName -Data $WebEvent.Data -State $state
                    Write-PodeJsonResponse -Value $res
                } catch {
                    Write-PodeJsonResponse -Value @{ error = $_.Exception.Message } -StatusCode 500
                }
            }
        }

        # ブラウザ自動起動
        Start-Process -FilePath "http://localhost:$($conf.Server.Port)"
    }
}