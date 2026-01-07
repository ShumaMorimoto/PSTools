# MyModule.psm1 の中

function Start-MyApp {
    # -----------------------------------------------------------
    # 1. 静的ファイルのパスを特定
    # -----------------------------------------------------------
    # $PSScriptRoot は、この .psm1 ファイルがあるフォルダを指します
    $moduleRoot = $PSScriptRoot 
    $staticFilesPath = Join-Path $moduleRoot "data"

    # デバッグ用にパス表示（確認用）
    Write-Host "Serving static files from: $staticFilesPath" -ForegroundColor Cyan

    # -----------------------------------------------------------
    # 2. サーバー起動
    # -----------------------------------------------------------
    Start-PodeServer {
        Add-PodeEndpoint -Address * -Port 8000 -Protocol Http

        # =======================================================
        # ★ ここがポイント：静的ファイルの配信設定
        # =======================================================
        # -Path '/'       : ブラウザのURLルート (http://localhost:8000/)
        # -Source ...     : 実際のファイル置き場 (MyModule/data)
        # -DefaultFile    : URLがファイル指定でない時に返すファイル
        # -------------------------------------------------------
        Add-PodeStaticRoute -Path '/' -Source $staticFilesPath -DefaultFile 'index.html'

        # ※ これだけで、dataフォルダ内のサブフォルダもすべて再帰的に公開されます。
        #   data/css/style.css      -> http://localhost:8000/css/style.css
        #   data/js/marker/lib.js   -> http://localhost:8000/js/marker/lib.js
        #   data/img/logo.png       -> http://localhost:8000/img/logo.png
        

        # =======================================================
        # ついでにさっきの API 自動公開も入れる
        # =======================================================
        # 自分自身の公開コマンドを取得してAPI化
        $myModule = Get-Module "MyModule" # 自分のモジュール名に合わせてください
        $cmds = $myModule.ExportedCommands.Keys

        Add-PodeRoute -Method POST -Path '/api/:cmd' -ScriptBlock {
            $cmd = $WebEvent.Parameters.cmd
            if ($cmd -in $cmds) {
                # モジュール内の関数を実行
                $res = & $cmd @($WebEvent.Data)
                Write-PodeJsonResponse -Value $res
            }
            else {
                Write-PodeJsonResponse -Value @{ error="Not Found" } -StatusCode 404
            }
        }
    }
}
