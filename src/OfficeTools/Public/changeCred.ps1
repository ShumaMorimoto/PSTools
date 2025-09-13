function changeCred() {
    $cred = Get-Credential -Username [OTConfig]::Settings.Credential.id

    $driver = Start-SeDriver -Browser Edge
    $driver.url = "http://comainu.cu.nri.co.jp/passwd_change/"

    Start-Sleep 2

    $driver.FindElementByName('AuthenticationID').sendKeys($settings.empNo)
    $driver.FindElementByName('OldPassword').sendKeys($settings.password)
    $driver.FindElementByName('NewPassword').sendKeys($cred.Password)
    $driver.FindElementByName('NewPasswordConfirm').sendKeys($cred.Password)
    $driver.FindElementByName('ChangePasswordButton').click()
    $driver.SwitchTo().Alert().Accept()

    $settings.password = ConvertFrom-SecureString -SecureString $cred.Password 
    ConvertTo-JSON $settings | Set-Content $file
}
