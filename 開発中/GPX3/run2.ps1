<#
    run2.ps1
    第1引数: ページ名 (省略時 sample.html)
    第2引数: 初期データ用 PSObject (省略時 $null)
#>

param(
    [Parameter(Position = 0)]
    [string]$PageName = "sample.html",

    [Parameter(Position = 1)]
    [PSObject]$InitialData = $null
)

# HttpListener を使うための型をロード
Add-Type -AssemblyName System.Net.HttpListener

# ---- 以降はあなたの既存コードをそのまま ----

$port = 8000
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

function Invoke-CustomProcess {
    param([psobject]$data, [string]$mode)
    $data | Add-Member NoteProperty processedBy ($mode + "PS") -Force
    $data | Add-Member NoteProperty processedAt (Get-Date).ToString("o") -Force
    if ($data.lat) { $data.lat = [math]::Round([double]$data.lat, 6) }
    if ($data.lon) { $data.lon = [math]::Round([double]$data.lon, 6) }
    return $data
}

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

    if ($path -eq "/") { $path = "/" + $PageName }

    switch -Regex ($path) {
        '^/fetchInitialData$' {
            # GET /fetchInitialData
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
            # POST /processSync
            $body = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding).ReadToEnd()
            try {
                $inObj = $body | ConvertFrom-Json -ErrorAction Stop
                $outObj = Invoke-CustomProcess $inObj "sync"
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
            # POST /processAsync
            $body = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding).ReadToEnd()
            try {
                $inObj = $body | ConvertFrom-Json -ErrorAction Stop
                $jobId = [guid]::NewGuid().ToString()
                $job = Start-Job -ScriptBlock {
                    param($data)
                    $data | Add-Member NoteProperty processedBy "asyncPS" -Force
                    $data | Add-Member NoteProperty processedAt (Get-Date).ToString("o") -Force
                    if ($data.lat) { $data.lat = [math]::Round([double]$data.lat, 6) }
                    if ($data.lon) { $data.lon = [math]::Round([double]$data.lon, 6) }
                    return $data
                } -ArgumentList $inObj

                $Global:JobTable[$jobId] = @{ Job = $job; Status = 'pending'; Result = $null }
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
        default {
            # 静的ファイル配信 (HTML/JS/CSS)
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
