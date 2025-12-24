using module RouteOptimizer

<#
    run2.ps1
    第1引数: ページ名 (省略時 sample.html)
    第2引数: 初期データ用 PSObject (省略時 $null)
#>
param(
    [Parameter(Position = 0)]
    [string]$PageName = "map.html",

    [Parameter(Position = 1)]
    [PSObject]$InitialData = $null
)

# HttpListener を使うための型をロード
Add-Type -AssemblyName System.Net.HttpListener

# ---- プロセス定義（ここをカスタマイズ） ----
$Global:Processes = @(
    @{
        Name   = "optimize"
        Action = {
            param($data)
            return Optimize-AreaRoute $data
        }
    }
    # 追加のプロセスをここに @{Name="process3"; Action={param($data,$mode) ... }} の形で追加
)

# ---- 以降は既存コードを改良 ----

$port = 8000  # 必要に応じて8080に変更
$prefix = "http://localhost:$port/"

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Listening on $prefix"

if ($InitialData) {
    $Global:CurrentData = $InitialData
    $initQuery = "?init=true"
}
else {
    $Global:CurrentData = @{}
    $initQuery = ""
}

$Global:JobTable = @{}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ブラウザ起動
Start-Process ($prefix + $PageName + $initQuery)

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $path = $req.Url.AbsolutePath
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

    Write-Host "Received request: Method=$($req.HttpMethod), Path=$path, Query=$($query | ConvertTo-Json -Compress)"  # サーバログ追加

    if ($path -eq "/") { $path = "/" + $PageName }

    switch -Regex ($path) {
        '^/fetchInitialData$' {
            # GET /fetchInitialData
            Write-Host "Processing /fetchInitialData"
            $json = $Global:CurrentData | ConvertTo-Json -Depth 10
            $b = [Text.Encoding]::UTF8.GetBytes($json)
            $res.ContentType = "application/json; charset=utf-8"
            $res.OutputStream.Write($b, 0, $b.Length)
            $res.Close()
        }
        '^/upload$' {
            if ($req.HttpMethod -ne 'POST') {
                $res.StatusCode = 405; $res.Close(); break
            }
            # POST /upload
            Write-Host "Processing /upload"
            $body = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding).ReadToEnd()
            try {
                $obj = $body | ConvertFrom-Json -ErrorAction Stop
                $Global:CurrentData = $obj
                $resp = @{ status = "ok" } | ConvertTo-Json
                $b = [Text.Encoding]::UTF8.GetBytes($resp)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
            }
            catch {
                $res.StatusCode = 400
                $err = @{ error = "invalid json"; detail = $_.Exception.Message } | ConvertTo-Json
                $b = [Text.Encoding]::UTF8.GetBytes($err)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
            }
            $res.Close()
        }
        '^/processSync$' {
            if ($req.HttpMethod -ne 'POST') {
                $res.StatusCode = 405; $res.Close(); break
            }
            # POST /processSync?name=xxx
            $name = $query.name ?? "default"
            $proc = $Global:Processes | Where-Object { $_.Name -eq $name }
            if (-not $proc) {
                $res.StatusCode = 404
                $err = @{ error = "process not found"; name = $name } | ConvertTo-Json
                $b = [Text.Encoding]::UTF8.GetBytes($err)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
                $res.Close(); break
            }
            Write-Host "Processing /processSync with name=$name"
            $body = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding).ReadToEnd()
            try {
                $inObj = $body | ConvertFrom-Json -ErrorAction Stop
                $outObj = & $proc.Action $inObj "sync"
                $json = $outObj | ConvertTo-Json -Depth 10
                $b = [Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
            }
            catch {
                $res.StatusCode = 400
                $err = @{ error = "invalid json"; detail = $_.Exception.Message } | ConvertTo-Json
                $b = [Text.Encoding]::UTF8.GetBytes($err)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
            }
            $res.Close()
        }
        '^/processAsync$' {
            if ($req.HttpMethod -ne 'POST') {
                $res.StatusCode = 405; $res.Close(); break
            }
            # POST /processAsync?name=xxx
            $name = $query.name ?? "default"
            $proc = $Global:Processes | Where-Object { $_.Name -eq $name }
            if (-not $proc) {
                $res.StatusCode = 404
                $err = @{ error = "process not found"; name = $name } | ConvertTo-Json
                $b = [Text.Encoding]::UTF8.GetBytes($err)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
                $res.Close(); break
            }
            Write-Host "Processing /processAsync with name=$name"
            $body = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding).ReadToEnd()
            try {
                $inObj = $body | ConvertFrom-Json -ErrorAction Stop
                $jobId = [guid]::NewGuid().ToString()
                $job = Start-Job -ScriptBlock {
                    param($action, $data, $mode)
                    & $action $data $mode
                } -ArgumentList $proc.Action, $inObj, "async"

                $Global:JobTable[$jobId] = @{ Job = $job; Status = 'pending'; Result = $null; ProcessName = $name }
                $resp = @{ jobId = $jobId; status = 'pending' } | ConvertTo-Json
                $b = [Text.Encoding]::UTF8.GetBytes($resp)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
            }
            catch {
                $res.StatusCode = 400
                $err = @{ error = "invalid json"; detail = $_.Exception.Message } | ConvertTo-Json
                $b = [Text.Encoding]::UTF8.GetBytes($err)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($b, 0, $b.Length)
            }
            $res.Close()
        }
        '^/processAsyncResult$' {
            if ($req.HttpMethod -ne 'GET') {
                $res.StatusCode = 405; $res.Close(); break
            }
            $jobId = $query.jobId
            if (-not $Global:JobTable.ContainsKey($jobId)) {
                $res.StatusCode = 404; $res.Close(); break
            }
            Write-Host "Processing /processAsyncResult for jobId=$jobId"
            $rec = $Global:JobTable[$jobId]
            if ($rec.Status -eq 'pending' -and $rec.Job.State -eq 'Completed') {
                $obj = Receive-Job -Job $rec.Job -ErrorAction SilentlyContinue
                Remove-Job  -Job $rec.Job -Force
                $rec.Result = $obj
                $rec.Status = 'completed'
            }
            if ($rec.Status -eq 'completed') {
                $out = @{ jobId = $jobId; status = 'completed'; result = $rec.Result }
            }
            else {
                $out = @{ jobId = $jobId; status = 'pending' }
            }
            $b = [Text.Encoding]::UTF8.GetBytes(($out | ConvertTo-Json -Depth 10))
            $res.ContentType = "application/json; charset=utf-8"
            $res.OutputStream.Write($b, 0, $b.Length)
            $res.Close()
        }
        '^/shutdown$' {
            if ($req.HttpMethod -ne 'POST') {
                $res.StatusCode = 405; $res.Close(); break
            }
            # POST /shutdown
            Write-Host "Processing /shutdown - Stopping server"
            $resp = @{ status = "shutting down" } | ConvertTo-Json
            $b = [Text.Encoding]::UTF8.GetBytes($resp)
            $res.ContentType = "application/json; charset=utf-8"
            $res.OutputStream.Write($b, 0, $b.Length)
            $res.Close()
            $listener.Stop()  # リスナーを停止してループを終了
        }
        default {
            # 静的ファイル配信 (HTML/JS/CSS)
            $filePath = Join-Path $scriptDir $path.TrimStart('/')
            if (Test-Path $filePath -PathType Leaf) {
                Write-Host "Serving static file: $filePath"
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
                Write-Host "404 Not Found: $path"
                $res.StatusCode = 404
            }
            $res.Close()
        }
    }
}

Write-Host "Server stopped"