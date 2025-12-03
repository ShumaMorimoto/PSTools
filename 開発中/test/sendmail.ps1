

Add-Type -Path "D:\tool\packages\MailKit.dll"
Add-Type -Path "D:\tool\packages\MimeKit.dll"


class GMailApp : MimeKit.MimeMessage {
    static [string]$account = "shumamorimoto@gmail.com"
    static [string]$aplpasscode = "rsbzlyaahobmslzj"
    static [MimeKit.BodyBuilder] $builder
    static [MailKit.Net.Smtp.SmtpClient] $smtp
    
    GmailApp(){
        $this.From.Add("shumamorimoto@gmail.com")
        [GmailApp]::builder = New-Object MimeKit.BodyBuilder
        [GmailApp]::smtp = New-Object MailKit.Net.Smtp.SmtpClient
    }
    sendEmail($to,$subject,$body){
        $this.To.Add($to)
        $this.Subject = $subject

        [GMailApp]::builder.TextBody = $body
        $this.Body = [GMailApp]::builder.ToMessageBody()

        [GmailApp]::smtp.Connect("smtp.gmail.com", 587, $false)
        [GmailApp]::smtp.Authenticate([GmailApp]::account, [GmailApp]::aplpasscode)

        [GmailApp]::smtp.Send([MimeKit.MimeMessage]$this)
        [GmailApp]::smtp.Disconnect($true)
    }
}


$gmail = New-Object GMailApp
$gmail.SendeMail("shumamorimoto@gmail.com","タイトル","場オディ")

