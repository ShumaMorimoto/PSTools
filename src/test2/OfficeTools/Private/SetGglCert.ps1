SetGglCert() {
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
