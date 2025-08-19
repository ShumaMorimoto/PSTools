# MyModule.psm1

#region --- Configuration Holder Class ---
# 設定を保持するためだけの、シンプルなクラス
class OTConfig {
    static [string]$confPath = "$env:APPDATA\OfficeTools"
    static [string]$confFile = $null
    static [object]$Settings = [ordered]@{}
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
    static [void] Load() {
        [OTConfig]::Settings = Get-Content -Path ([OTConfig]::confFile) -Raw | ConvertFrom-Json -AsHashtable
    }
    static [void] Save() {
        [OTConfig]::Settings.LastUpdated = (Get-Date)
        [OTConfig]::Settings | ConvertTo-Json -Depth 5 | Set-Content -Path ([OTConfig]::confFile)
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
