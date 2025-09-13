function Split-Module {
    param (
        [string]$SourcePath
    )

    if (-not $SourcePath) {
        $psm1File = Get-ChildItem -Path (Get-Location) -Filter *.psm1 | Select-Object -First 1
        if (-not $psm1File) {
            throw "❌ カレントディレクトリに .psm1 ファイルが見つかりません。"
        }
        $SourcePath = $psm1File.FullName
        Write-Host "📄 SourcePath を自動選択: $SourcePath"
    }

    $structurePath = Join-Path $script:TemplateRoot 'ModuleStructure.template.json'
    $structure = Get-Content $structurePath | ConvertFrom-Json

    function Ensure-Directory {
        param ($path)
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
        }
    }

    # 🔍 入力ファイル確認とモジュール名取得
    if (-not (Test-Path $SourcePath)) {
        throw "❌ ファイルが存在しません: $SourcePath"
    }
    $resolved = Resolve-Path -Path $SourcePath
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($resolved.ProviderPath)
    $outRoot = Join-Path (Get-Location) $moduleName

    # 📁 出力ディレクトリ準備（テンプレートに基づく）
    $structure.Folders | ForEach-Object {
        Ensure-Directory (Join-Path $outRoot $_)
    }

    # 🔍 AST解析
    $rootAst = [System.Management.Automation.Language.Parser]::ParseFile($resolved.ProviderPath, [ref]$null, [ref]$null)
    if (-not $rootAst) {
        throw "❌ ASTの解析に失敗しました。構文エラーの可能性があります。"
    }

    function Get-ExportedFunctions {
        param ($ast)
        $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.CommandElements[0].Value -eq 'Export-ModuleMember'
            }, $true) |
        ForEach-Object {
            $_.CommandElements |
            Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } |
            ForEach-Object { $_.Value }
        }
    }

    function Split-Class {
        param ($classAst, $outDir)
        $className = $classAst.Name
        $code = $classAst.Extent.Text
        $outPath = Join-Path $outDir "Classes\$className.ps1"
        Set-Content -Path $outPath -Value $code -Encoding UTF8
        Write-Host "🧩 クラス分割: $className → Classes/"
    }

    function Split-Function {
        param ($funcAst, $isExported, $outDir)
        $funcName = $funcAst.Name
        $folder = if ($isExported) { "Public" } else { "Private" }
        $code = $funcAst.Extent.Text
        $outPath = Join-Path $outDir "$folder\$funcName.ps1"
        Set-Content -Path $outPath -Value $code -Encoding UTF8
        Write-Host "🔧 関数分割: $funcName → $folder/"
    }

    function Get-ScriptBlockAssignments {
        param ($ast)
        $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Right.Find({ $args[0] -is [System.Management.Automation.Language.ScriptBlockAst] }, $true)
            }, $true)
    }

    function Get-UpdateTypeDataCalls {
        param ($ast)
        $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.CommandElements[0].Value -eq 'Update-TypeData'
            }, $true)
    }

    function Split-TypeExtension {
        param ($assignments, $updateCalls, $outDir)

        $extensionLines = @()

        foreach ($assign in $assignments) {
            $varName = $assign.Left.VariablePath.UserPath
            $code = $assign.Extent.Text
            $extensionLines += $code
        }

        foreach ($call in $updateCalls) {
            $extensionLines += $call.Extent.Text
        }

        if ($extensionLines.Count -gt 0) {
            $extPath = Join-Path $outDir "Extensions\System.DateTime.Extension.ps1"
            Ensure-Directory (Split-Path $extPath)
            Set-Content -Path $extPath -Value ($extensionLines -join "`r`n`r`n") -Encoding UTF8
            Write-Host "🧠 型拡張分割: System.DateTime → Extensions/"
        }
    }

    $exported = Get-ExportedFunctions $rootAst
    Write-Host "📤 Export対象関数: $($exported -join ', ')"

    $rootAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.TypeDefinitionAst]
        }, $true) | ForEach-Object {
        Split-Class $_ $outRoot
    }

    $rootAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            -not ($node.Parent -and $node.Parent.Parent -is [System.Management.Automation.Language.TypeDefinitionAst])
        }, $true) | ForEach-Object {
        $isExported = $exported -contains $_.Name
        Split-Function $_ $isExported $outRoot
    }

    $assignments = Get-ScriptBlockAssignments $rootAst
    $updateCalls = Get-UpdateTypeDataCalls $rootAst
    Split-TypeExtension $assignments $updateCalls $outRoot

    Write-Host "✅ 分割完了: $SourcePath → $outRoot"
}