using module D:\tool\Repository\PSTools\RouteOptimizer

# ============================================================
# RunspaceHost クラス定義
# ============================================================
class RunspaceHost {
    [Runspace]$Runspace
    [PowerShell]$PS
    [hashtable]$State
    [object]$AsyncHandle
    [scriptblock]$StartScript

    RunspaceHost([string[]]$ModulePath, [scriptblock]$StartScript) {

        # --- 初期セッション状態 ---
        $iss = [InitialSessionState]::CreateDefault()

        # --- モジュールを string[] のまま Import ---
        if ($ModulePath) {
            $iss.ImportPSModule($ModulePath)
        }

        # --- Runspace 作成 ---
        $this.Runspace = [RunspaceFactory]::CreateRunspace($iss)
        $this.Runspace.Open()

        # --- PowerShell インスタンス ---
        $this.PS = [PowerShell]::Create()
        $this.PS.Runspace = $this.Runspace

        # --- State 初期化 ---
        $this.State = [hashtable]::Synchronized(@{
                Stop       = $false
                Generation = 0
                UpdatedAt  = $null
                BestDist   = [double]::PositiveInfinity
                BestRoute  = @()
            })

        $this.StartScript = $StartScript
    }

    [object] Start([object]$data) {
        if ($this.AsyncHandle) { return @{ status = "already running" } }

        $this.State.Input = $data
        $this.State.Stop = $false

        $this.PS.Commands.Clear()
        $this.PS.AddScript($this.StartScript).AddArgument($this.State).AddArgument($data) | Out-Null

        $this.AsyncHandle = $this.PS.BeginInvoke()
        return @{ status = "started" }
    }

    [object] Stop() {
        if (-not $this.AsyncHandle) { return @{ status = "not running" } }

        $this.State.Stop = $true
        $this.PS.EndInvoke($this.AsyncHandle)
        $this.AsyncHandle = $null
        return @{ status = "stopped" }
    }
}
# ============================================================
# Run-App（InitialData + ?init=true + /fetchInitialData 対応）
# ============================================================
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

# ============================================================
# ここまでが統合版 runGA.ps1（責務順序修正版）
# ============================================================

$DummyLogic = {
    param($State, $data)

    Write-Host "[DummyLogic] Start"

    for ($i = 1; $i -le 10; $i++) {

        if ($State.Stop) {
            Write-Host "[DummyLogic] Stop requested"
            break
        }

        $State.Generation = $i
        $State.UpdatedAt = Get-Date
        $State.BestDist = 1000 - ($i * 10)
        $State.BestRoute = @(0, 1, 2, 3)

        Write-Host "[DummyLogic] Generation $i"
        Start-Sleep -Milliseconds 300
    }

    Write-Host "[DummyLogic] Finished"
}

$DummyRoutes = @{
    Start   = {
        param($data, $rh)
        $rh.Start($data)
    }
    Stop    = {
        param($data, $rh)
        $rh.Stop()
    }
    Status  = {
        param($data, $rh)
        @{
            Generation = $rh.State.Generation
            UpdatedAt  = $rh.State.UpdatedAt
            BestDist   = $rh.State.BestDist
        }
    }
    GetBest = {
        param($data, $rh)
        $rh.State.BestRoute | ForEach-Object {
            $rh.State.Places[$_]
        }
    }
    Optimize    = {
        param($data, $rh)
        Optimize-AreaRoute $data
    }
}


$towns = [GPXDocumentFactory]::FromCItyTOwns("葉山町", $false)
$pso = $towns.GetTrkPts() | ForEach-Object { [GPXDocument]::ElementToPSO($_) }

Run-App -StartScript $DummyLogic -Routes $DummyRoutes -PageName D:\tool\Repository\PSTools\開発中\GPX3\sample3.html -InitialData $pso

