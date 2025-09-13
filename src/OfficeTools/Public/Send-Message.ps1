function Send-Message {
    param(
        [string]$to,
        [string]$subject,
        [string]$body
    )
    $builder = New-Object MimeKit.BodyBuilder
    $smtp = New-Object MailKit.Net.Smtp.SmtpClient
    $message = New-Object MimeKit.MimeMessage

    $message.From.Add([OTConfig]::Settings.Gmail.account)
    $message.To.Add($to)
    $message.Subject = $subject

    $builder.TextBody = $body
    $message.Body = $builder.ToMessageBody()

    $smtp.Connect("smtp.gmail.com", 587, $false)
    $smtp.Authenticate([OTConfig]::Settings.Gmail.account, [OTConfig]::Settings.Gmail.passcord)
    $smtp.Send($message) 
    $smtp.Disconnect($true)
}
