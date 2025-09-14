GetMtmPAT() {
        $pat = [OTConfig]::Settings.Mattermost.pat
        if ($null -eq $pat) {
            $pat = [OTConfig]::SetMtmPAT()
        }
        return $pat
    }
