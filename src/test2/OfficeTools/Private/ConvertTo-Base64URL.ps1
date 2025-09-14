function ConvertTo-Base64URL {
    <#
        .Synopsis
            Convert text or byte array to URL friendly Base64

        .DESCRIPTION
            Used for preparing the JWT token format.

        .PARAMETER bytes
            The bytes to be converted

        .PARAMETER text
            The text to be converted

        .EXAMPLE
            ConvertTo-Base64URL -text $headerJSON

        .EXAMPLE
            ConvertTo-Base64URL -Bytes $rsa.SignData($toSign,"SHA256")
    #>
    param
    (
        [Parameter(ParameterSetName = 'Bytes')]
        [System.Byte[]]$Bytes,

        [Parameter(ParameterSetName = 'String')]
        [string]$text
    )

    if ($Bytes) { $base = $Bytes }
    else { $base = [System.Text.Encoding]::UTF8.GetBytes($text) }
    $base64Url = [System.Convert]::ToBase64String($base)
    $base64Url = $base64Url.Split('=')[0]
    $base64Url = $base64Url.Replace('+', '-')
    $base64Url = $base64Url.Replace('/', '_')
    $base64Url
}
