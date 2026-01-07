# 事前に: Install-Module -Name Pode -Scope CurrentUser

function Run-App-Pode {
    param(
        [string]$ModulePath,
        [scriptblock]$StartScript,
        [object]$InitialData,
        [hashtable]$Routes, 
        [string]$PageName
    )

    # --- 1. パス解決 ---
    $full = Resolve-Path $PageName
    $rootDir = Split-Path $full -Parent
    $topFile = Split-Path $full -Leaf
    $libDir  = Join-Path $script:ModuleRoot "lib/js"

    # --- 2. サーバー構成 ---
    Start-PodeServer {
        # ポート設定
        Add-PodeEndpoint -Address * -Port 8000 -Protocol Http

        # --- 3. モジュールの読み込み (重要: ここで書けば全タスクで有効) ---
        if ($ModulePath) { Import-Module $ModulePath }

        # --- 4. 状態管理の初期化 ---
        # RunspaceHost.State の代わり。スレッドセーフに管理される
        $state = @{
            Phase      = 'Idle'
            Result     = @{}
            Generation = 0
            UpdatedAt  = $null
            Stop       = $false
        }
        Set-PodeSharedState -Name 'AppState' -Value $state

        # --- 5. バックグラウンドタスク (RunspaceHostの代わり) ---
        Add-PodeTask -Name 'Worker' -ScriptBlock {
            param($e)
            
            # 状態取得
            $state = Get-PodeSharedState -Name 'AppState'
            $state.Stop = $false
            $state.Phase = 'Running'
            $state.Generation++
            Set-PodeSharedState -Name 'AppState' -Value $state

            # ユーザーのロジック実行
            # $StartScript を実行する。引数として $state と入力データ($e.Data)を渡す
            try {
                & $e.Argument.Script $state $e.Argument.Input
            }
            catch {
                $state.Phase = "Error: $_"
            }
            finally {
                # 完了時の状態更新
                if ($state.Phase -eq 'Running') { $state.Phase = 'Completed' }
                $state.UpdatedAt = (Get-Date)
                Set-PodeSharedState -Name 'AppState' -Value $state
            }
        }

        # --- 6. API ルーティング ---

        # (A) 静的ファイル (自動で MIME 対応、キャッシュ対応)
        Add-PodeStaticRoute -Path "/" -Source $rootDir -DefaultFile $topFile
        if (Test-Path $libDir) {
            Add-PodeStaticRoute -Path "/runapp/lib/js" -Source $libDir
        }

        # (B) 初期データ取得
        Add-PodeRoute -Method GET -Path '/fetchInitialData' -ScriptBlock {
            # InitialData変数はクロージャで渡ってくる
            Write-PodeJsonResponse -Value $InitialData
        }

        # (C) Shutdown
        Add-PodeRoute -Method POST -Path '/shutdown' -ScriptBlock {
            Write-PodeJsonResponse -Value @{ status = "shutting down" }
            Stop-PodeServer
        }

        # (D) メイン API ( /api?name=Start 等 )
        # 既存のJSを変えないよう、クエリパラメータ ?name=... を処理する
        Add-PodeRoute -Method POST -Path '/api' -ScriptBlock {
            $name = $WebEvent.Query.name
            $inputData = $WebEvent.Data

            # 標準機能の定義 (Routesが空の場合)
            if ($name -eq 'Start') {
                # タスクを非同期でキック
                Invoke-PodeTask -Name 'Worker' -ArgumentList @{ Script = $StartScript; Input = $inputData }
                Write-PodeJsonResponse -Value @{ status = "started" }
            }
            elseif ($name -eq 'Stop') {
                $s = Get-PodeSharedState -Name 'AppState'
                $s.Stop = $true
                Set-PodeSharedState -Name 'AppState' -Value $s
                Write-PodeJsonResponse -Value @{ status = "stopping_signal_sent" }
            }
            elseif ($name -eq 'Status') {
                $s = Get-PodeSharedState -Name 'AppState'
                Write-PodeJsonResponse -Value $s
            }
            else {
                # カスタムRoutesがあればここで処理
                # (Pode化するならここもPodeRouteにするのが理想だが、互換維持ならInvokeする)
                 Write-PodeJsonResponse -Value @{ error = "Unknown command" } -StatusCode 404
            }
        }
        
        # --- 7. ブラウザ起動 ---
        # サーバー起動直後に実行されるフック
        Register-PodeEvent -Type ServerStart -ScriptBlock {
            $url = "http://localhost:8000/$topFile"
            if ($InitialData) { $url += "?init=true" }
            Start-Process $url
            Write-Host "Listening on http://localhost:8000/" -ForegroundColor Cyan
        }
    }
}
