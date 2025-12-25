function Run-App {
    param(
        [string]$ModulePath,        # 1. ロジックの物理パス
        [scriptblock]$StartScript,  # 2. ロジックのエントリーポイント
        [object]$InitialData,       # 3. 起動時に指定する初期データ
        [hashtable]$Routes,         # 4. API
        [string]$PageName           # 5. UI
    )

    # --- PageName を絶対パスに解決 ---
    $full = Resolve-Path $PageName
    $rootDir = Split-Path $full -Parent
    $topFile = Split-Path $full -Leaf

    Write-Host "Hosting root: $rootDir"
    Write-Host "Top page: $topFile"

    # --- RunspaceHost 作成 ---
    $rh = [RunspaceHost]::new($ModulePath, $StartScript)

    # --- InitialData を保持（HTML に渡すため） ---
    $initData = $InitialData

    # --- Web サーバ開始 ---
    $port = 8000
    $prefix = "http://localhost:$port/"

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add($prefix)
    $listener.Start()

    Write-Host "Listening on $prefix"

    # --- ブラウザ起動 URL を決定 ---
    if ($InitialData) {
        $url = "${prefix}${topFile}?init=true"
    }
    else {
        $url = "${prefix}${topFile}"
    }
    Start-Process $url

    # ============================================================
    # メインループ
    # ============================================================
    while ($listener.IsListening) {

        try {
            $ctx = $listener.GetContext()
        }
        catch {
            break
        }

        $req = $ctx.Request
        $res = $ctx.Response
        $path = $req.Url.AbsolutePath

        # --- アクセスログ ---
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "[$timestamp] $($req.HttpMethod) $($req.RawUrl)"

        # --- クエリ解析 ---
        $query = @{}
        if ($req.Url.Query.Length -gt 1) {
            foreach ($p in $req.Url.Query.TrimStart('?').Split('&')) {
                $kv = $p.Split('=')
                $query[$kv[0]] = if ($kv.Length -gt 1) {
                    [Uri]::UnescapeDataString($kv[1])
                }
                else { '' }
            }
        }

        switch -Regex ($path) {

            # --------------------------------------------------------
            # API 呼び出し
            # --------------------------------------------------------
            '^/api$' {
                $name = $query.name

                if (-not $Routes.ContainsKey($name)) {
                    $res.StatusCode = 404
                    $res.Close()
                    break
                }

                $body = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding).ReadToEnd()
                $data = if ($body) { $body | ConvertFrom-Json } else { $null }

                $result = & $Routes[$name] $data $rh
                $json = $result | ConvertTo-Json -Depth 10

                $bytes = [Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
            }

            # --------------------------------------------------------
            # 初期データ取得エンドポイント
            # --------------------------------------------------------
            '^/fetchInitialData$' {
                $json = $initData | ConvertTo-Json -Depth 10
                $bytes = [Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
            }

            # --------------------------------------------------------
            # shutdown
            # --------------------------------------------------------
            '^/shutdown$' {
                if ($req.HttpMethod -ne 'POST') {
                    $res.StatusCode = 405; $res.Close(); break
                }

                Write-Host "Processing /shutdown - Stopping server"
                $resp = @{ status = "shutting down" } | ConvertTo-Json
                $b = [Text.Encoding]::UTF8.GetBytes($resp)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
                $res.Close()

                $listener.Stop()
            }

            # --------------------------------------------------------
            # 静的ファイル配信
            # --------------------------------------------------------
            default {
                $filePath = Join-Path $rootDir $path.TrimStart('/')

                if (Test-Path $filePath -PathType Leaf) {
                    $ext = [IO.Path]::GetExtension($filePath).ToLowerInvariant()
                    $ct = @{
                        '.html' = 'text/html; charset=utf-8'
                        '.js'   = 'application/javascript; charset=utf-8'
                        '.css'  = 'text/css'
                        '.json' = 'application/json; charset=utf-8'
                    }[$ext] ?? 'application/octet-stream'

                    $bytes = [IO.File]::ReadAllBytes($filePath)
                    $res.ContentType = $ct
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                }
                else {
                    $res.StatusCode = 404
                }

                $res.Close()
            }
        }
    }

    Write-Host "Server stopped"
}
