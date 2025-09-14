OTPowerpointDAO([string]$path) {
        [OTPowerpointDAO]::initialize()
        $this.presen = [OTPowerpointDAO]::powerpoint.Presentations.Open($path)
    }
