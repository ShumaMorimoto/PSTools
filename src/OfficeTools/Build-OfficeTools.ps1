param (
    [string]$ModulePath = "$PSScriptRoot",
    [string]$ModuleName = "OfficeTools",
    [string]$ModuleVersion = "1.0.0",
    [string]$Author = "shuma"
)

# --- クラス依存解析 ---
function Get-ClassDependencies {
    param ($classAst)
    $deps = @()
    foreach ($base in $classAst.BaseTypes) {
        if ($base.TypeName.FullName -ne 'object') {
            $deps += $base.TypeName.FullName
        }
    }
    return $deps
}

function Sort-Classes {
    param ($classMap)
    $sorted = @()
    $visited = @{}
    function Visit($name) {
        if ($visited[$name]) { return }
        $visited[$name] = $true
        foreach ($dep in $classMap[$name]) {
            if ($classMap.ContainsKey($dep)) {
                Visit $dep
            }
        }
        $sorted += $name
    }
    foreach ($name in $classMap.Keys) { Visit $name }
    return $sorted
}

# --- クラス読み込み ---
$classDir = Join-Path $ModulePath "Classes"
$classFiles = Get-ChildItem $classDir -Filter *.ps1 | Where-Object { $_.Name -ne "AllClasses.ps1" }
$classMap = @{}
$classCode = @{}
foreach ($file in $classFiles) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
    $classAst = $ast.Find({ $_ -is [System.Management.Automation.Language.TypeDefinitionAst] }, $true)
    if ($classAst) {
        $name = $classAst.Name
        $classMap[$name] = Get-ClassDependencies $classAst
        $classCode[$name] = Get-Content $file.FullName -Raw
    }
}
$orderedClasses = Sort-Classes $classMap

# --- 関数読み込み ---
$privateDir = Join-Path $ModulePath "Private"
$publicDir  = Join-Path $ModulePath "Public"
$privateFunctions = Get-ChildItem $privateDir -Filter *.ps1
$publicFunctions  = Get-ChildItem $publicDir  -Filter *.ps1

# --- psm1 の生成 ---
$psm1Path = Join-Path $ModulePath "$ModuleName.psm1"
$psm1 = @()
$psm1 += "# Auto-generated module: $ModuleName"
$psm1 += "Set-StrictMode -Version Latest"
$psm1 += ""

foreach ($name in $orderedClasses) {
    $psm1 += $classCode[$name]
    $psm1 += ""
}

$psm1 += "# Load Private Functions"
foreach ($file in $privateFunctions) {
    $psm1 += ". `"$($PSScriptRoot)\Private\$($file.Name)`""
}
$psm1 += ""

$psm1 += "# Load Public Functions"
foreach ($file in $publicFunctions) {
    $psm1 += ". `"$($PSScriptRoot)\Public\$($file.Name)`""
}
$psm1 += ""

$exportNames = $publicFunctions.Name | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) }
$psm1 += "Export-ModuleMember -Function @("
$psm1 += ($exportNames | ForEach-Object { "    '$_'" }) -join "
"
$psm1 += ")"

$psm1 -join "
" | Set-Content $psm1Path -Encoding UTF8

# --- psd1 の更新 ---
$psd1Path = Join-Path $ModulePath "$ModuleName.psd1"
New-ModuleManifest -Path $psd1Path `
    -RootModule "$ModuleName.psm1" `
    -ModuleVersion $ModuleVersion `
    -Author $Author `
    -Description "Production module for $ModuleName" `
    -FunctionsToExport $exportNames

# --- AllClasses.ps1 の再生成（開発用） ---
$allClassesPath = Join-Path $classDir "AllClasses.ps1"
$allClasses = $orderedClasses | ForEach-Object {
    ". `"$PSScriptRoot\$($_).ps1`""
}
$allClasses -join "
" | Set-Content $allClassesPath -Encoding UTF8

Write-Host "✅ Module built: $ModuleName" -ForegroundColor Green
Write-Host "✅ AllClasses.ps1 updated for development use" -ForegroundColor Cyan
