#using module OfficeTools
#$workspaceFolder = Split-Path $PSScriptRoot -Parent
# モジュールパスを構築
#$localModulePath = Join-Path $workspaceFolder "OfficeTools\OfficeTools.psm1"
# モジュール読み込み
#Import-Module $localModulePath -Force
#Write-Host "📦 ローカルモジュールを読み込みました: $localModulePath"

using module OfficeTools

# OAuth2 アクセストークン（事前に取得しておく）
$gm = [OTGMailDAO]::new()

# Gmail API エンドポイント
$headers = @{
    Authorization = "Bearer $([OTGmailDAO]::accessToken)"
}

# クエリ: 30日以上前のプロモーションメール
#$q = "category:promotions"
$encodedQuery = [System.Web.HttpUtility]::UrlEncode($q)
$searchUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages"

Write-Host $searchUrl

$response = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get

try {
    $response | ConvertTo-Json -Depth 5
} catch {
    $_.Exception.Response.GetResponseStream() | 
        % { New-Object System.IO.StreamReader($_) } | 
        % { $_.ReadToEnd() } | 
        Out-String | Write-Host
}

if ($response.messages) {
    foreach ($msg in $response.messages) {
        $deleteUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/$($msg.id)"
#        Invoke-RestMethod -Uri $deleteUrl -Headers $headers -Method Delete
        Write-Host "削除: $($msg.id)"
    }
} else {
    Write-Host "削除対象のメールはありませんでした。"
}