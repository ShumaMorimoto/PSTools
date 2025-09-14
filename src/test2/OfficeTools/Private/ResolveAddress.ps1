ResolveAddress([string]$name) {
        if (($name -eq "") -or $null -eq $name) {
            return $null
        }
        if ($name -match "(.{3})　(.{3})") {   
            $name = ($Matches[1] -replace "　", "") + " " + ($Matches[2] -replace "　", "")
        }
        $recip = [OTOutlookDAO]::namespace.CreateRecipient($name)
        $user = @{氏名 = $name }

        if ($recip.Resolve()) {     
            $user.氏名 = $recip.Name
            $user.メール = $recip.AddressEntry.GetExchangeUser().PrimarySmtpAddress

            if ($recip.Name -match "(.+　.+)\((\d+)\)(.+)$") {
                $user.氏名 = $Matches[1]
                $user.内線番号 = $Matches[2]
                $user.所属 = $Matches[3]
            }
        }       
        return $user
    }
