function downloadCript([string]$url, [string]$key, [string]$downloadPath) {
    $settings = getCred
    node "$PSScriptRoot\scripts\downloadCript.js" -u $url -k $key --id $settings.id --pw $settings.pw -d $downloadPath
}
