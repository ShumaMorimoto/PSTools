param(
    [string]$Json
)

# ✅ map.html のパス（ここだけ変えればOK）
$MapFile = "D:\tool\tmp\開発中\map.html"

Add-Type -AssemblyName System.Net.HttpListener

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8000/")
$listener.Start()

Write-Host "Server running at http://localhost:8000"
Write-Host "map.html = $MapFile"

# ✅ JSON が指定されたら POST、無ければ GET
if ($Json) {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("Content-Type", "application/json")
    $wc.UploadString("http://localhost:8000/map.html", "POST", $Json)
}
Start-Process "http://localhost:8000/map.html"

# ✅ サーバーループ
while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $req = $context.Request
        $res = $context.Response

        $path = $req.Url.AbsolutePath

        # ✅ map.html
        if ($path -eq "/map.html") {

            if ($req.HttpMethod -eq "GET") {
                $html = Get-Content -Raw -Encoding UTF8 $MapFile
                $res.ContentType = "text/html; charset=utf-8"
            }
            elseif ($req.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd()
                $html = $body + "`n" + (Get-Content -Raw -Encoding UTF8 $MapFile)
                $res.ContentType = $req.ContentType
            }

            $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
            $res.StatusCode = 200
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.Close()
            continue
        }

        # ✅ 静的ファイル（JS / CSS / PNG / JPG / SVG）
        $localPath = "D:\tool\tmp\開発中" + $path
        if (Test-Path $localPath) {
            $bytes = [System.IO.File]::ReadAllBytes($localPath)

            switch -Regex ($localPath) {
                "\.js$"  { $res.ContentType = "text/javascript" }
                "\.css$" { $res.ContentType = "text/css" }
                "\.png$" { $res.ContentType = "image/png" }
                "\.jpg$" { $res.ContentType = "image/jpeg" }
                "\.svg$" { $res.ContentType = "image/svg+xml" }
                default  { $res.ContentType = "application/octet-stream" }
            }

            $res.StatusCode = 200
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.Close()
            continue
        }

        # ✅ favicon は無視（404でOK）
        if ($path -eq "/favicon.ico") {
            $res.StatusCode = 404
            $res.Close()
            continue
        }

        # ✅ その他は 404
        $res.StatusCode = 404
        $res.Close()
    }
    catch {
        break
    }
}