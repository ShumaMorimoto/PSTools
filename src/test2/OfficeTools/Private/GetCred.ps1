GetCred() {
        $cred = [OTConfig]::Settings.Credential
        if (($null -eq $cred) -or ([OTConfig]::Settings.LastUpdated -lt (Get-Date).addMonths(-6))) {
            $cred = [OTConfig]::SetCred()
        }
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $cred.password))
        [OTConfig]::password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        return $cred
    }
