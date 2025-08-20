Import-Module PSGSuite

$path = (Get-Item "$env:APPDATA\OfficeTools\*googleusercontent.com.json").FullName

Set-PSGSuiteConfig -ConfigName "PSGSuite" `
  -SetAsDefaultConfig `
  -ClientSecretsPath $path `
  -AdminEmail "shumamorimoto@gmail.com"


# スプレッドシートIDと範囲を指定
$spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU"  # ← 実際のIDに置き換えてください
$range = "Sheet1!A1:C3"                # ← 取得したい範囲を指定

# 値を取得
$response = Get-GSValue -SpreadsheetId $spreadsheetId -Range $range

# 結果を表示
$response.Values | ForEach-Object {
    $_ -join " | "
}

https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&response_type=code&client_id=182418997846-15lo6cvtccvebifmdjp4f7etbh5hmvgg.apps.googleusercontent.com&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&scope=https%3A%2F%2Fwww.google.com%2Fm8%2Ffeeds%20https%3A%2F%2Fmail.google.com%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgmail.settings.basic%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgmail.settings.sharing%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdrive%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Ftasks%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Ftasks.readonly
