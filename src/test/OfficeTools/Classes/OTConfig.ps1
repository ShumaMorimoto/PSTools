class OTConfig {
    static [string]$confPath = $null
    static [string]$confFile = $null
    static [object]$Settings = [ordered]@{}
    static [string]$password = $null
    static [void] initialize() {
        [OTConfig]::confPath = Join-Path $env:ProgramData 'OfficeTools'
        New-Item -Path $([OTConfig]::confPath) -ItemType Directory -Force -ErrorAction Stop | Out-Null
        [OTConfig]::confFile = Join-Path ([OTConfig]::confPath) "settings.json"

        if (Test-Path ([OTConfig]::confFile)) {
            # JSONから読み込んだPSCustomObjectを、そのまま静的プロパティに代入
            [OTConfig]::Load()
        }
        else {
            # デフォルト設定をPSCustomObjectとして作成し、静的プロパティに代入
            [OTConfig]::Settings = [ordered]@{
                Mattermost  = [ordered]@{url = "https://mattermost.aslead.cloud/api/v4"; pat = "octj7bd18tf37edjc8tyhq1t8r" }
                Confluence  = [ordered]@{url = "https://sd10.aslead.cloud/wiki/rest/pat/latest/tokens" }
                Google      = [ordered]@{certPath = $null, $iss = "psgsuite-client@smart-surf-425115-s5.iam.gserviceaccount.com" }
                Gmail       = [ordered]@{account = $null; passcode = $null }
                LastUpdated = (Get-Date)
            }
            # ファイルに保存
            [OTConfig]::Save()
        }
    }
    static [void] Load() {
        [OTConfig]::Settings = Get-Content -Path ([OTConfig]::confFile) -Raw | ConvertFrom-Json -AsHashtable
        $cred = [OTConfig]::Settings.Credential
        if ($cred -and $cred.password) {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $cred.password))
            [OTConfig]::password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
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
        [OTConfig]::password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
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
            $pat = [OTConfig]::SetMtmPAT()
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
        $tokens = [OTConfig]::Settings.Confluence.tokens
        if ($null -eq $tokens) {
            $tokens = [OTConfig]::SetCnflToken()
        }
        if (
            ($null -eq $tokens.expiringAt) -or `
            ([Datetime]($tokens.expiringAt) -lt (Get-Date).AddDays(20))
        ) {
            $tokens = [OTConfig]::UpdateCnflToken($tokens.rawToken)
        }
        return $tokens
    } 
    static [object] UpdateCnflToken([string]$token) {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type"  = "application/json; charset=UTF-8"
        }
        $body = @{
            name               = "myToken"
            expirationDuration = 90
        }
        $json = ConvertTo-JSON -Compress $body
        $tokens = Invoke-RestMethod -Uri ([OTConfig]::Settings.Confluence.url) -Body $json -Method "POST" -Headers ($headers)
        [OTConfig]::Settings.Confluence.tokens = $tokens
        [OTConfig]::Save()
        return $tokens
    }
    static [object] SetCnflToken() {
        $base64AuthInfo = [Convert]::ToBase64String( `
                [Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f `
                    ([OTConfig]::Settings.Credential.id -replace "cu.nri.co.jp", "nri.co.jp"), `
                        [OTConfig]::password))`
        )

        $headers = @{
            Authorization  = ("Basic {0}" -f $base64AuthInfo)
            "Content-Type" = "application/json; charset=UTF-8"
        }   
        $body = @{
            name               = "myToken"
            expirationDuration = 90
        }
        $json = ConvertTo-JSON -Compress $body
        $tokens = Invoke-RestMethod -Uri ([OTConfig]::Settings.Confluence.url) -Body $json -Method "POST" -Headers ($headers)
        [OTConfig]::Settings.Confluence.tokens = $tokens
        [OTConfig]::Save()
        return $tokens
    }
    static [object] SetGglCert() {
        $iss = Read-Host "GoogleのISSアカウントは？（変更しない場合は空）"
        if ($iss -eq "") {
            $iss = [OTConfig]::Settings.Google.iss
        }
        $filepath = (Read-Host "GoogleのCertFileの場所は？") -replace '"', ''
        
        if (Test-Path $filepath) { 
            $path = (Get-Item $filepath).FullName
            [OTConfig]::Settings.Google = [ordered]@{certPath = $path; iss = $iss }
            [OTConfig]::Save()
            return  [OTConfig]::Settings.Google
        }
        else {
            return "ERROR ($filepath)"
        }
    }  
    static [object] SetGmail() {
        $account = Read-Host "メールアカウントは？"
        $passcord = Read-Host "アプリパスコードは？"
        [OTConfig]::Settings.Gmail = @{account = $account; passcord = $passcord }
        [OTConfig]::Save()
        return [OTConfig]::Settings.Gmail
    }
}
