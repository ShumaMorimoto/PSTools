# モジュールルート（このファイルの場所）
$script:ModuleToolsRoot = $PSScriptRoot
$script:TemplateRoot     = Join-Path $script:ModuleToolsRoot 'Templates'

# dot-source public functions
Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function Split-Module, Build-Module, Get-ClassDependencyTree