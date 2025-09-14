function Build-ModuleRelease {
    param (
        [string]$ModuleRoot = $PSScriptRoot
    )

    $moduleName = Split-Path -Leaf $ModuleRoot
    $templatePath = Join-Path $ModuleRoot 'Templates'
    $psm1Path = Join-Path $ModuleRoot "$moduleName.psm1"
    $psd1Path = Join-Path $ModuleRoot "$moduleName.psd1"

    function Backup-IfExists {
        param ([string]$filePath)
        if (Test-Path $filePath) {
            $timestamp = Get-Date -Format 'yyyyMMddHHmmssfff'
            $backupPath = "$filePath.$timestamp"
            Copy-Item -Path $filePath -Destination $backupPath
            Write-Host "📦 バックアップ作成: $backupPath"
        }
    }

    # ─── クラス定義の統合 ───
    $classFiles = Get-ClassInheritanceOrder -ClassesPath "$ModuleRoot\Classes"
    $classBlock = $classFiles | ForEach-Object { Get-Content $_ } | Out-String

    # ─── PSM1生成 ───
    $psm1Template = Get-Content "$templatePath\Module.psm1.template" -Raw
    $psm1Content = $psm1Template -replace '{{Classes}}', { return $classBlock }

    Backup-IfExists $psm1Path
    Set-Content $psm1Path -Value $psm1Content -Encoding UTF8

    # ─── PSD1生成 ───
    $psd1Template = Get-Content "$templatePath\Module.psd1.template" -Raw

    if (Test-Path $psd1Path) {
        $meta = Import-PowerShellDataFile -Path $psd1Path
        $versionParts = $meta.ModuleVersion -split '\.'
        $versionParts[2] = [int]$versionParts[2] + 1
        $newVersion = $versionParts -join '.'
        $author = $meta.Author
        $description = $meta.Description
        $guid = $meta.GUID
    }
    else {
        $newVersion = '1.0.0'
        $author = ''
        $description = ''
        $guid = [guid]::NewGuid().ToString()
    }

    $requiredAssemblies = Get-ChildItem "$ModuleRoot\lib\*.dll" | ForEach-Object {
        "'$($_.Name)'"
    } 

    $functionsToExport = @()
    if (Test-Path "$ModuleRoot\Public") {
        $functionsToExport = Get-ChildItem "$ModuleRoot\Public\*.ps1" | ForEach-Object {
            "'$([System.IO.Path]::GetFileNameWithoutExtension($_.Name))'"
        }
    }
    $functionsToExport = $functionsToExport -join ', '

    $psd1Content = $psd1Template `
        -replace '{{ModuleVersion}}', $newVersion `
        -replace '{{Author}}', $author `
        -replace '{{Description}}', $description `
        -replace '{{GUID}}', $guid `
        -replace '{{RequiredAssemblies}}', ($requiredAssemblies -join ', ') `
        -replace '{{FunctionsToExport}}', $functionsToExport

    Backup-IfExists $psd1Path
    Set-Content $psd1Path -Value $psd1Content -Encoding UTF8

    Write-Host "✅ モジュールビルド完了: $ModuleRoot"
}