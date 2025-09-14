SetCred() {
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
