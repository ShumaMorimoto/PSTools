getPAT() {
        $pat = [OTConfig]::Settings.Mattermost.pat
        [MattermostDAO]::headers = @{
            "Authorization" = "Bearer " + $pat
            "Content-Type"  = "application/json; charset=UTF-8"
        }
        return $pat
    }
