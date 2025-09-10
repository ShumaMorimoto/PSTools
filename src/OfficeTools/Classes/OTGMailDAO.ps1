class OTGMailDAO:OTGoogleDAO {
    static $scope = "https://www.googleapis.com/auth/gmail.modify"
    static $accessToken = $null

    OTGMailDAO() {
        $this.initialize()
    }
    [void] initialize() {
        [OTGMailDAO]::GetToken()
    }
    static [void] GetToken() {
        [OTGMailDAO]::accessToken = [OTGoogleDAO]::GetToken([OTGMailDAO]::scope)
    }
}
