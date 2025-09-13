class OTPowerpointDAO {
    static [object] $powerpoint
    [object] $presen

    OTPowerpointDAO([string]$path) {
        [OTPowerpointDAO]::initialize()
        $this.presen = [OTPowerpointDAO]::powerpoint.Presentations.Open($path)
    }
    static [void] initialize() {
        if ($null -eq [OTPowerpointDAO]::powerpoint) {
            [OTPowerpointDAO]::powerpoint = New-Object -ComObject PowerPoint.Application
        }
    }
    [PpTable] GetTable() {
        return New-Object PpTable($this.presen)
    }
}
