param(
    [string]$PageName = "../sample3.html",
    [PSObject]$InitialData = $null
)

Add-Type -AssemblyName System.Net.HttpListener

# --- RunspaceHost の準備 ---
$startScript = {
    param($State, $data)

    # data を State に展開（ロジック側の責務）
    $State.Places = $data.Places
    $State.BestRoute = @()
    $State.BestDist = [double]::PositiveInfinity
    $State.Generation = 0
    $State.Stop = $false

    RunGALogic -State $State -Places $State.Places
}

$Routes = @{
    Start   = { param($data) $runhost.Start($data) }   # 汎用
    Stop    = { param($data) $runhost.Stop() }         # 汎用

    Status  = { param($data)                       # カスタム
        @{
            Generation = $runhost.State.Generation
            UpdatedAt  = $runhost.State.UpdatedAt
            BestDist   = $runhost.State.BestDist
        }
    }

    GetBest = { param($data)                       # カスタム
        $runhost.State.BestRoute | ForEach-Object {
            $runhost.State.Places[$_]
        }
    }
}

$runhost = [RunspaceHost]::new(
    "D:\tool\Repository\PSTools\開発中\GPX3\GA\galogic.ps1", 
    $startScript
)

# --- Web サーバ ---
$port = 8000
$prefix = "http://localhost:$port/"

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "Listening on $prefix"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ブラウザ起動（プロセス監視のため PassThru）
$browser = Start-Process ($prefix + $PageName) -PassThru

# --- メインループ（非ブロッキング + ブラウザ監視 + アクセスログ） ---
while ($listener.IsListening -and -not $browser.HasExited) {

    # 非同期でリクエスト待ち
    $async = $listener.BeginGetContext($null, $null)

    # 最大 100ms だけ待つ（タイムアウト）
    $index = [System.Threading.WaitHandle]::WaitAny(@($async.AsyncWaitHandle), 100)

    if ($index -eq 0) {
        # リクエストが来た
        $ctx = $listener.EndGetContext($async)
        $req = $ctx.Request
        $res = $ctx.Response

        # --- アクセスログ ---
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $method    = $req.HttpMethod
        $url       = $req.RawUrl
        $remote    = $req.RemoteEndPoint.Address.ToString()
        Write-Host "[$timestamp] $method $url from $remote"

        $path = $req.Url.AbsolutePath

        # クエリ解析
        $query = @{}
        if ($req.Url.Query.Length -gt 1) {
            foreach ($p in $req.Url.Query.TrimStart('?').Split('&')) {
                $kv = $p.Split('=')
                $query[$kv[0]] = if ($kv.Length -gt 1) {
                    [Uri]::UnescapeDataString($kv[1])
                } else { '' }
            }
        }

        if ($path -eq "/") { $path = "/" + $PageName }

        switch -Regex ($path) {

            '^/api$' {
                $name = $query.name
                if (-not $Routes.ContainsKey($name)) {
                    $res.StatusCode = 404
                    $res.Close()
                    break
                }

                $body = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding).ReadToEnd()
                $data = if ($body) { $body | ConvertFrom-Json } else { $null }

                $result = & $Routes[$name] $data
                $json = $result | ConvertTo-Json -Depth 10

                $bytes = [Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
            }

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

            default {
                $filePath = Join-Path $scriptDir $path.TrimStart('/')
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
    else {
        # タイムアウト側：ブラウザが死んでたら終わり
        if ($browser.HasExited) {
            Write-Host "Browser exited - stopping listener"
            $listener.Stop()
            break
        }
    }
}

Write-Host "Server stopped"
