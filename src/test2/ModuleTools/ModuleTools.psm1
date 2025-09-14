# ─── モジュールフォルダ構成 ───
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:configPath = Join-Path $script:ModuleRoot "config"
$script:libPath = Join-Path $script:ModuleRoot "lib"
$script:ExtensionsPath = Join-Path $script:ModuleRoot "Extensions"
$script:ClassesPath = Join-Path $script:ModuleRoot "Classes"
$script:PrivatePath = Join-Path $script:ModuleRoot "Private"
$script:PublicPath = Join-Path $script:ModuleRoot "Public"
$script:nodePath = Join-Path $script:ModuleRoot "node"
$script:dataPath = Join-Path $script:ModuleRoot "data"
$script:TemplatesPath = Join-Path $script:ModuleRoot "Templates"

# ─── DLL 読み込み ───


# ─── クラス定義 ───


# ─── 関数読み込み ───
. "$PSScriptRoot\Public\Convert-PsmToModule.ps1"
. "$PSScriptRoot\Public\Get-ClassDependencyTree.ps1"
. "$PSScriptRoot\Public\New-Module.ps1"
. "$PSScriptRoot\Public\New-ModuleScaffold.ps1"
. "$PSScriptRoot\Private\Ensure-ModuleStructure.ps1"
. "$PSScriptRoot\Private\SettingsManager.ps1"

# ─── 公開関数 ───
Export-ModuleMember -Function Convert-PsmToModule, Get-ClassDependencyTree, New-Module, New-ModuleScaffold
