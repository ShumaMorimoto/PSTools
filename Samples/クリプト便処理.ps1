using module OfficeTools

$downLoadPath = 'D:\tool\tmp1\'
$tobox = '\\Outlook データ ファイル\仕分け親'
$id = "s-morimoto@cu.nri.co.jp"
$pw = "xxxxx"

#メールからURLを切り出し
$o = New-Object OTOutlookDao
$box = $o.GetMailTable()
$to  = $o.GetMailTable($tobox)
$mails = $box.Search($null, { $args[0].Subject -eq "URLテスト" })

foreach ($mail in $mails) {
    if ($mail.body -match 'HYPERLINK "(http://.+)"') {
        $url = $Matches[1]
    }
    $prefix = $mail.ReceivedTime.toString('yyyyMMdd')

    #$driver = Start-SeDriver -Browser Chrome 
    #$driver.url = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=4765445b-32c6-49b0-83e6-1d93765276ca&redirect_uri=https%3A%2F%2Fwww.office.com%2Flandingv2&response_type=code%20id_token&scope=openid%20profile%20https%3A%2F%2Fwww.office.com%2Fv2%2FOfficeHome.All&response_mode=form_post&nonce=638596868180177352.ZDQ2MTQ5MGItZGU4Ni00N2JjLThjYzMtY2M2MmYyYzJlNDY2ZDkxOTRkZGMtZWE1OS00MDQ2LThmZWQtNTVmMmYyNmE4MDE4&ui_locales=ja&mkt=ja&client-request-id=a2f7f8b0-eaad-4fc5-a137-816525d99daa&state=OJqMJs__3Y0zOAOuBcNoSEa15FxCcylEda2uW3ZNTIzXuuZMfRebXAOMiHzFdMUn1VMqUz-32PKnZiz-EBGa0KCnsHieiFpIrQf30JobZsV2OIqbxQNT2pI1DaloombUPvW8GSD02actbrnJL8tYomu1KcksYUHPYGtku_uYJhx8FxNXEE-w2NKpU6uI0rpf2UZN33yJeXbNEu_Y001vhlbMFN2GvogHBW0FVtdTAZEkdGal_1cwPqqJntMSUKVjHm-7jA4L1v9u0Evg00tjHQ&x-client-SKU=ID_NET8_0&x-client-ver=7.5.1.0'
    #sleep 2
    #$driver.FindElementByID('i0116').sendKeys("shumamorimoto@gmail.com")
    #$driver.FindElementById("idSIButton9").click()
    #sleep 2
    #$driver.FindElementById('i0118').sendKeys('password')
    #$driver.FindElementById('idSIButton9').click()
    #$driver.FindElementById("idBtn_Back").click()

    Get-ChildItem $downLoadPath | Where-Object { $_.name -notlike '20??????_*' } | Rename-Item -NewName { $prefix + $_.name }
    Get-ChildItem $downLoadPath | Where-Object { $_.name -like '*.zip' } | ForEach-Object {
        $path = $DownLoadPath + $_.name
        $dir = $DownLoadPath + ($_.name -replace '\..+', '')
        Expand-Archive -Path $path -DestinationPath $dir
    }

    $to.AddMail($mail)
}