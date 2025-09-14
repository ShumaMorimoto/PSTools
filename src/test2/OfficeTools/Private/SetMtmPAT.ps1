SetMtmPAT() {
        $pat = Read-Host "MattermostのPATは？"
        [OTConfig]::Settings.Mattermost = @{pat = $pat }
        [OTConfig]::Save()
        return $pat
    }
