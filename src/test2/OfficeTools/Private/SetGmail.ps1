SetGmail() {
        $account = Read-Host "メールアカウントは？"
        $passcord = Read-Host "アプリパスコードは？"
        [OTConfig]::Settings.Gmail = @{account = $account; passcord = $passcord }
        [OTConfig]::Save()
        return [OTConfig]::Settings.Gmail
    }
