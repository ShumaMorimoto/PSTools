function New-Module {
    param (
        [string]$ModuleRoot = (Get-Location).Path
    )

    # ─────────────────────────────────────────────
    function Resolve-TemplatePaths {
        param (
            [string]$ModuleRoot
        )

        $targetTemplateRoot = Join-Path $ModuleRoot 'Templates'
        $templateFiles = @(
            'Module.psm1.template',
            'Module.psd1.template',
            'ModuleStructure.template.json'
        )

        if (-not (Test-Path $targetTemplateRoot)) {
            New-Item -ItemType Directory -Path $targetTemplateRoot | Out-Null
        }

        foreach ($file in $templateFiles) {
            $targetPath = Join-Path $targetTemplateRoot $file
            if (-not (Test-Path $targetPath)) {
                $sourcePath = Join-Path $script:TemplatesPath $file
                Copy-Item -Path $sourcePath -Destination $targetPath
                Write-Host "📁 テンプレートコピー: $file → $targetTemplateRoot"
            }
        }

        return @{
            TemplateRoot     = $targetTemplateRoot
            StructurePath    = Join-Path $targetTemplateRoot 'ModuleStructure.template.json'
            Psm1TemplatePath = Join-Path $targetTemplateRoot 'Module.psm1.template'
            Psd1TemplatePath = Join-Path $targetTemplateRoot 'Module.psd1.template'
        }
    }

    function Generate-FolderBlock {
        param ($structure)
        $lines = @()
        $lines += '$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path'
        $lines += $structure.Folders | ForEach-Object {
            '$script:{0}Path = Join-Path $script:ModuleRoot "{0}"' -f $_
        }
        return $lines -join "`r`n"
    }

    function Get-ClassInheritanceOrder {
        param ($classFiles)

        $classMap = @{}
        $classCodeMap = @{}

        foreach ($file in $classFiles) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$null)
            $classDef = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.TypeDefinitionAst] }, $true)
            if ($classDef) {
                $className = $classDef.Name
                $baseName = if ($classDef.BaseTypes.Count -gt 0) { $classDef.BaseTypes[0].TypeName.Name } else { $null }
                $classMap[$className] = $baseName
                $classCodeMap[$className] = Get-Content $file -Raw
            }
        }

        $script:sorted = @()
        $visited = @{}

        function Visit($name) {
            if ($visited[$name]) { return }
            $visited[$name] = $true
            $base = $classMap[$name]
            if ($base -and $classMap.ContainsKey($base)) {
                Visit $base
            }
            $script:sorted += $name
        }

        foreach ($name in $classMap.Keys) {
            Visit $name
        }

        return $script:sorted | ForEach-Object { $classCodeMap[$_] }
    }

    function Get-FunctionNames {
        param ($folder)
        Get-ChildItem -Path $folder -Filter *.ps1 -ErrorAction SilentlyContinue |
        ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
    }

    function Generate-DotSourceBlock {
        param ($publicFuncs, $privateFuncs)

        $lines = @()
        # Public 関数
        $lines += $publicFuncs  | ForEach-Object { '. "$PSScriptRoot\Public\{0}.ps1"' -f $_ }

        # Private 関数
        $lines += $privateFuncs | ForEach-Object { '. "$PSScriptRoot\Private\{0}.ps1"' -f $_ }

        # Extension 型拡張
        $extensionDir = Join-Path $PSScriptRoot 'Extensions'
        if (Test-Path $extensionDir) {
            $extensionFiles = Get-ChildItem -Path $extensionDir -Filter '*.Extension.ps1' -File
            $lines += $extensionFiles | ForEach-Object {
                '. "$PSScriptRoot\Extensions\{0}"' -f $_.Name
            }
        }
        return $lines -join "`r`n"
    }

    function Generate-ExportBlock {
        param ($publicFuncs)
        if ($publicFuncs.Count -eq 0) {
            return ''
        }
        return 'Export-ModuleMember -Function ' + ($publicFuncs -join ', ')
    }

    function Get-DllPaths {
        param ([string]$libPath)
        if (-not (Test-Path $libPath)) { return @() }
        Get-ChildItem -Path $libPath -Filter *.dll -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object { $_.Name }
    }

    function Generate-AddTypeBlock {
        param ([string[]]$dllNames)
        if (-not $dllNames -or $dllNames.Count -eq 0) { return '' }
        return ($dllNames | ForEach-Object {
                'Add-Type -Path "$script:ModuleRoot\lib\{0}"' -f $_
            }) -join "`r`n"
    }

    function Generate-RequiredAssembliesLine {
        param ([string[]]$dllNames)
        if (-not $dllNames -or $dllNames.Count -eq 0) { return '' }
        return ($dllNames | ForEach-Object {
                "'lib\{0}'" -f $_
            }) -join ", "
    }

    # ─────────────────────────────────────────────
    # メイン処理
    $moduleName = Split-Path $ModuleRoot -Leaf
    $psm1Path = Join-Path $ModuleRoot "$moduleName.psm1"
    $psd1Path = Join-Path $ModuleRoot "$moduleName.psd1"

    $templatePaths = Resolve-TemplatePaths -ModuleRoot $ModuleRoot 

    $structure = Get-Content $templatePaths.StructurePath | ConvertFrom-Json
    $psm1Template = Get-Content $templatePaths.Psm1TemplatePath -Raw
    $psd1Template = Get-Content $templatePaths.Psd1TemplatePath -Raw

    $folderBlock = Generate-FolderBlock $structure

    $classesPath = Join-Path $ModuleRoot "Classes"
    $publicPath = Join-Path $ModuleRoot "Public"
    $privatePath = Join-Path $ModuleRoot "Private"
    $libPath = Join-Path $ModuleRoot "lib"

    $classFiles = Get-ChildItem -Path $classesPath -Filter *.ps1 -File | Select-Object -ExpandProperty FullName
    $classCodeList = Get-ClassInheritanceOrder $classFiles
    $classBlock = $classCodeList -join "`r`n`r`n"

    $publicFuncs = @(Get-FunctionNames $publicPath)
    $privateFuncs = @(Get-FunctionNames $privatePath)
    $dotSourceBlock = Generate-DotSourceBlock $publicFuncs $privateFuncs
    $exportBlock = Generate-ExportBlock $publicFuncs

    $dllNames = Get-DllPaths $libPath
    $addTypeBlock = Generate-AddTypeBlock $dllNames
    $requiredAssemblies = Generate-RequiredAssembliesLine $dllNames

    # 📝 psm1生成（安全な置換）
    $psm1Content = $psm1Template
    $psm1Content = [Regex]::Replace($psm1Content, '{{FolderPaths}}', { return $folderBlock })
    $psm1Content = [Regex]::Replace($psm1Content, '{{Classes}}', { return $classBlock })
    $psm1Content = [Regex]::Replace($psm1Content, '{{DotSource}}', { return $dotSourceBlock })
    $psm1Content = [Regex]::Replace($psm1Content, '{{AddTypeBlock}}', { return $addTypeBlock })
    $psm1Content = [Regex]::Replace($psm1Content, '{{Export}}', { return $exportBlock })

    Set-Content -Path $psm1Path -Value $psm1Content -Encoding UTF8
    Write-Host "✅ $moduleName.psm1 を生成しました: $psm1Path"

    # 📝 psd1生成
    $quotedFuncs = $publicFuncs | ForEach-Object { "'$_'" }
    $funcsExportLine = ($quotedFuncs -join ", ")

    $psd1Content = $psd1Template `
        -replace '{{ModuleName}}', $moduleName `
        -replace '{{ModuleVersion}}', '1.0.0' `
        -replace '{{GUID}}', ([guid]::NewGuid().ToString()) `
        -replace '{{Author}}', 'Shuma' `
        -replace '{{Description}}', 'Auto-generated module manifest.' `
        -replace '{{ExportFunctions}}', $funcsExportLine `
        -replace '{{RequiredAssemblies}}', $requiredAssemblies

    Set-Content -Path $psd1Path -Value $psd1Content -Encoding UTF8
    Write-Host "✅ $moduleName.psd1 を生成しました: $psd1Path"
}