# ModuleRoot/build/build-prod.ps1
$root = Join-Path $PSScriptRoot '..'

$orderedClasses = @('Base.ps1', 'Derived.ps1')  # 依存順
$classContent = $orderedClasses | ForEach-Object {
    Get-Content "$root/Classes/$_"
}

$functionFiles = Get-ChildItem "$root/Functions" -Filter '*.ps1'
$functionContent = $functionFiles | ForEach-Object {
    Get-Content $_.FullName
}

$psm1Content = @()
$psm1Content += $classContent
$psm1Content += $functionContent
$psm1Content += "`nExport-ModuleMember -Function Get-Item, Set-Item"

$psm1Content | Set-Content "$root/MyModule.psm1" -Encoding UTF8