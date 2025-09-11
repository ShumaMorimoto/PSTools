# ModuleRoot/build/build-dev.ps1
$root = Join-Path $PSScriptRoot '..'
$classFiles = Get-ChildItem "$root/Classes" -Filter '*.ps1' | Sort-Object Name
$funcFiles  = Get-ChildItem "$root/Functions" -Filter '*.ps1' | Sort-Object Name

$lines = @()
foreach ($file in $classFiles + $funcFiles) {
    $relativePath = $file.FullName.Replace($root, '.')
    $lines += ". '$relativePath'"
}

$lines | Set-Content "$root/Dev.psm1" -Encoding UTF8