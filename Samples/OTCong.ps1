# MyModule.psm1

#region --- Configuration Holder Class ---
# 設定を保持するためだけの、シンプルなクラス
class OTConfig {
    static [string]$confPath = "$env:APPDATA\OfficeTools"
    static [string]$confFile = $null
    static [object]$Settings = [ordered]@{}
    static [string]$confluUrl = "https://sd10.aslead.cloud/wiki/rest/pat/latest/tokens"
    static [void] Load() {
        [OTConfig]::Settings = Get-Content -Path ([OTConfig]::confFile) -Raw | ConvertFrom-Json -AsHashtable
    }
    static [void] Save() {
        [OTConfig]::Settings.LastUpdated = (Get-Date)
        [OTConfig]::Settings | ConvertTo-Json -Depth 5 | Set-Content -Path ([OTConfig]::confFile)
    }
    static [object] GetCred() {
        $cred = [OTConfig]::Settings.Credential
        if (($null -eq $cred) -or ([OTConfig]::Settings.LastUpdated -lt (Get-Date).addMonths(-6))) {
            $cred = [OTConfig]::SetCred()
        }
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $cred.password))
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $cred.password = $password
        return $cred
    } 
    static [object] SetCred() {
        $cred = @{}
        $empNo = Read-Host "社員コードは？(ex.x1234)"
        $_cred = Get-Credential
        $cred.add("empNo", $empNo)
        $cred.add("id", $_cred.UserName)
        $cred.add("password", (ConvertFrom-SecureString -SecureString $_cred.Password))
        [OTConfig]::Settings.Credential = $cred
        [OTConfig]::Save()
        return $cred
    }  
    static [string] GetMtmPAT() {
        $pat = [OTConfig]::Settings.Mattermost.pat
        if ($null -eq $pat) {
            $pat = [OTConfig]::SetCred()
        }
        return $pat
    } 
    static [string] SetMtmPAT() {
        $pat = Read-Host "MattermostのPATは？"
        [OTConfig]::Settings.Mattermost = @{pat = $pat }
        [OTConfig]::Save()
        return $pat
    }
    static [string] GetCnflToken() {
        $tokens = [OTConfig]::Settings.Confluence
        if ($null -eq $tokens) {
            $token = Read-Host "ConfluenceのTokenは？"
            $tokens = @{rawToken = $token }
        }
        if (
            ($null -eq $tokens.expiringAt) -or `
            ([Datetime]($tokens.expiringAt) -lt (Get-Date).AddDays(20))
        ) {
            $tokens = [OTConfig]::SetCnflToken($tokens.rawToken)
        }
        return $tokens
    } 
    static [object] SetCnflToken([string]$token) {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type"  = "application/json; charset=UTF-8"
        }
        $body = @{
            name               = "myToken"
            expirationDuration = 90
        }
        $json = ConvertTo-JSON -Compress $body
        $response = Invoke-RestMethod -Uri [OTConfig]::baseurl -Body $json -Method "POST" -Headers ($headers)
        $tokens = (ConvertFrom-JSON  -AsHashtable $response)
        [OTConfig]::Settings.Mattermost = $tokens
        [OTConfig]::Save()
        return $tokens
    }
}
#endregion

#region --- Module Internals ---
function Initialize-Configuration {
    New-Item -Path $([OTConfig]::confPath) -ItemType Directory -Force -ErrorAction Stop | Out-Null
    [OTConfig]::confFile = Join-Path ([OTConfig]::confPath) "settings.json"

    if (Test-Path ([OTConfig]::confFile)) {
        # JSONから読み込んだPSCustomObjectを、そのまま静的プロパティに代入
        [OTConfig]::Load()
    }
    else {
        # デフォルト設定をPSCustomObjectとして作成し、静的プロパティに代入
        [OTConfig]::Settings = [ordered]@{
            LastUpdated = (Get-Date)
        }
        # ファイルに保存
        [OTConfig]::Save()
    }
}
#endregion

# --- モジュール読み込み時の実行ブロック ---
Initialize-Configuration
