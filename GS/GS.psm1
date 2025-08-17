#if (-not ("Google.Apis.Sheets.v4.SheetsService" -as [Type])) {
    Add-Type -Path "$PSScriptRoot\Google.Apis.Core.dll"
    Add-Type -Path "$PSScriptRoot\Google.Apis.Auth.dll"
    Add-Type -Path "$PSScriptRoot\Google.Apis.dll"
    Add-Type -Path "$PSScriptRoot\Google.Apis.Sheets.v4.dll"
#}


[Google.Apis.Auth.OAuth2.GoogleCredential] -as [type]
