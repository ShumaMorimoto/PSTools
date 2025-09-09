<#
.SYNOPSIS
    Converts a single PowerShell script file into a structured module.
.DESCRIPTION
    This script parses a PowerShell script to identify classes and functions, then organizes them into a standard module structure (Public, Private, Classes folders).
    It automatically generates the .psm1 and .psd1 files, ensuring compatibility between Windows PowerShell 5.1 and PowerShell 7+.
    - Functions are considered 'Public' if they are listed in an 'Export-ModuleMember' command within the source script. All other functions are 'Private'.
    - Each class and function is saved into its own .ps1 file.
    - The .psd1 manifest is created with the appropriate parameters for the detected PowerShell version.
.PARAMETER SourcePath
    The path to the source .ps1 or .psm1 file to be converted.
.PARAMETER OutputPath
    The directory where the new module folder will be created. Defaults to the current directory.
.PARAMETER ModuleVersion
    The version of the module. Defaults to '1.0.0'.
.PARAMETER Author
    The author of the module. Defaults to the current username.
.PARAMETER Force
    If specified, overwrites the destination module directory if it already exists.
.EXAMPLE
    .\Convert-ScriptToModule.ps1 -SourcePath C:\Scripts\MyAwesomeScript.ps1
.EXAMPLE
    .\Convert-ScriptToModule.ps1 -SourcePath .\MyFunctions.ps1 -OutputPath C:\MyModules -Force
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$SourcePath,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$OutputPath = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$ModuleVersion = '1.0.0',

    [Parameter(Mandatory = $false)]
    [string]$Author = $env:USERNAME,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

try {
    # --- 1. 初期設定とパスの解決 ---
    Write-Verbose "Starting module conversion process for '$SourcePath'."
    $SourceFile = Resolve-Path -Path $SourcePath
    $ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile.ProviderPath)
    $ModulePath = Join-Path -Path $OutputPath -ChildPath $ModuleName

    if (Test-Path $ModulePath) {
        if ($Force) {
            if ($PSCmdlet.ShouldProcess($ModulePath, "Remove existing directory")) {
                Remove-Item -Path $ModulePath -Recurse -Force
            }
        } else {
            throw "The destination directory '$ModulePath' already exists. Use -Force to overwrite."
        }
    }

    Write-Host "Creating module '$ModuleName' at: '$ModulePath'" -ForegroundColor Green
    $publicDir  = Join-Path $ModulePath "Public"
    $privateDir = Join-Path $ModulePath "Private"
    $classesDir = Join-Path $ModulePath "Classes"
    $null = New-Item -Path $publicDir  -ItemType Directory
    $null = New-Item -Path $privateDir -ItemType Directory
    $null = New-Item -Path $classesDir -ItemType Directory

    # --- 2. ASTを使用してソースコードを解析 ---
    Write-Verbose "Parsing source file with Abstract Syntax Tree (AST)..."
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($SourceFile.ProviderPath, [ref]$null, [ref]$null)

    # 公開関数名を特定 (Export-ModuleMemberで指定されているもの)
    $publicFunctionNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $exportCommands = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] -and $args[0].GetCommandName() -eq 'Export-ModuleMember' }, $true)
    foreach ($command in $exportCommands) {
        $funcParam = $command.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq 'Function' }
        if ($funcParam) {
            $argument = $funcParam.Argument
            if ($argument -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                $publicFunctionNames.Add($argument.Value) | Out-Null
            } elseif ($argument -is [System.Management.Automation.Language.ArrayExpressionAst]) {
                $argument.SubExpression.FindAll({$args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst]}, $false) | ForEach-Object {
                    $publicFunctionNames.Add($_.Value) | Out-Null
                }
            }
        }
    }
    
    # --- 3. クラスと関数をファイルに分割 ---
    
    # クラスの処理
    $allClasses = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.TypeDefinitionAst] }, $true)
    $classNames = @()
    foreach ($classAst in $allClasses) {
        $className = $classAst.Name
        $classNames += $className
        $filePath = Join-Path $classesDir "$($className).ps1"
        if ($PSCmdlet.ShouldProcess($filePath, "Create class file")) {
            $classAst.Extent.Text | Out-File -FilePath $filePath -Encoding utf8
            Write-Verbose "Created class file for '$className'."
        }
    }

    # 関数の処理
    $allFunctions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    $privateFunctionNames = @()
    foreach ($functionAst in $allFunctions) {
        $functionName = $functionAst.Name
        $fileContent = $functionAst.Extent.Text

        if ($publicFunctionNames.Contains($functionName)) {
            $filePath = Join-Path $publicDir "$($functionName).ps1"
            if ($PSCmdlet.ShouldProcess($filePath, "Create public function file")) {
                $fileContent | Out-File -FilePath $filePath -Encoding utf8
                Write-Verbose "Created public function file for '$functionName'."
            }
        } else {
            $privateFunctionNames += $functionName
            $filePath = Join-Path $privateDir "$($functionName).ps1"
            if ($PSCmdlet.ShouldProcess($filePath, "Create private function file")) {
                $fileContent | Out-File -FilePath $filePath -Encoding utf8
                Write-Verbose "Created private function file for '$functionName'."
            }
        }
    }

    # --- 4. .psm1 ファイルの作成 ---
    $psm1Path = Join-Path $ModulePath "$($ModuleName).psm1"
    $psm1Content = @"
# PowerShell Script Module: $ModuleName
Set-StrictMode -Version Latest

# --- Load Private Functions ---
\$privateFunctions = Get-ChildItem -Path (Join-Path \$PSScriptRoot 'Private') -Filter '*.ps1'
foreach (\$functionFile in \$privateFunctions) {
    . \$functionFile.FullName
}

# --- Load Public Functions ---
\$publicFunctions = Get-ChildItem -Path (Join-Path \$PSScriptRoot 'Public') -Filter '*.ps1'
foreach (\$functionFile in \$publicFunctions) {
    . \$functionFile.FullName
}

# --- Export Members ---
# Note: Classes are automatically discovered by 'using module ...'.
# Exporting functions makes them available via 'Import-Module'.

Export-ModuleMember -Function @(
    '$($publicFunctionNames -join "',`n    '")'
)
"@
    if ($PSCmdlet.ShouldProcess($psm1Path, "Create PSM1 file")) {
        $psm1Content | Out-File -FilePath $psm1Path -Encoding utf8
        Write-Verbose "Created PSM1 file."
    }

    # --- 5. .psd1 (マニフェスト) ファイルの作成 ---
    $psd1Path = Join-Path $ModulePath "$($ModuleName).psd1"
    $manifestParams = @{
        Path                  = $psd1Path
        RootModule            = "$($ModuleName).psm1"
        ModuleVersion         = $ModuleVersion
        Author                = $Author
        Description           = "Module '$ModuleName' generated from '$($SourceFile.Name)'."
        FunctionsToExport     = $publicFunctionNames
        # PowerShell 7+ では NestedModules でクラスファイルを指定するのが堅牢
        # PowerShell 5.1 では ClassesToExport が必要
    }

    if ($PSCmdlet.ShouldProcess($psd1Path, "Create PSD1 manifest file")) {
        # PowerShell のバージョンに応じてマニフェスト作成のロジックを変更
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # PowerShell 7+ : NestedModules と ClassesToExport を両方使うのが推奨
            Write-Verbose "Creating manifest for PowerShell 7+."
            $classFilesRelative = $classNames | ForEach-Object { "Classes\$_.ps1" }
            $manifestParams.Add('NestedModules', @("Classes\*")) # フォルダワイルドカードで指定
            $manifestParams.Add('ClassesToExport', $classNames)
        } else {
            # Windows PowerShell 5.1 : ClassesToExport のみ
            Write-Verbose "Creating manifest for Windows PowerShell 5.1."
            $manifestParams.Add('ClassesToExport', $classNames)
        }
        
        # New-ModuleManifest コマンドを実行
        New-ModuleManifest @manifestParams
        Write-Verbose "Created PSD1 manifest file."
    }

    Write-Host "`nModule '$ModuleName' created successfully!" -ForegroundColor Green
    Write-Host "Directory structure:"
    Get-ChildItem -Path $ModulePath -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($ModulePath.Length)
        Write-Host (" " * ($_.PSParentPath.Length - $ModulePath.Length)) -NoNewline
        Write-Host "└── $($_.Name)"
    }
}
catch {
    Write-Error "An error occurred during module conversion: $_"
}
