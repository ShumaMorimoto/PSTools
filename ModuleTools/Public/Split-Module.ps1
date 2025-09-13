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

    if (-not (Test-Path $SourcePath)) {
        throw "❌ ファイルが存在しません: $SourcePath"
    }

    $resolved = Resolve-Path -Path $SourcePath
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($resolved.ProviderPath)
    $outRoot = Join-Path (Get-Location) $moduleName

    $structure.Folders | ForEach-Object {
        Ensure-Directory (Join-Path $outRoot $_)
    }

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

    # ✅ 修馬さんのオリジナル抽出ロジック（修正なし）
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
    function Get-UsedScriptBlockNames {
        param ($updateCalls)
        $updateCalls | ForEach-Object {
            $_.CommandElements |
            Where-Object {
                $_ -is [System.Management.Automation.Language.CommandParameterAst] -and
                $_.ParameterName -eq 'Value'
            } |
            ForEach-Object {
                $arg = $_.Argument
                if ($arg -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    $arg.VariablePath.UserPath
                }
                elseif ($arg -is [System.Management.Automation.Language.CommandExpressionAst]) {
                    $arg.Expression -as [System.Management.Automation.Language.VariableExpressionAst] |
                    ForEach-Object { $_.VariablePath.UserPath }
                }
            }
        }
    }
    function Get-UsedScriptBlockNamesFromUpdateTypeData {
        param ($ast)

        $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.CommandElements[0].Value -eq 'Update-TypeData'
            }, $true) | ForEach-Object {
            $elements = $_.CommandElements
            for ($i = 0; $i -lt $elements.Count - 1; $i++) {
                $current = $elements[$i]
                $next = $elements[$i + 1]

                if ($current -is [System.Management.Automation.Language.CommandParameterAst] -and
                    $current.ParameterName -eq 'Value' -and
                    $next -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    $next.VariablePath.UserPath
                }
            }
        } | Where-Object { $_ }
    }

    function FilterUsedScriptBlocks {
        param ($assignments, $usedNames)
        $assignments | Where-Object {
            $_.Left.VariablePath.UserPath -in $usedNames
        }
    }

    function Split-TypeExtension {
        param ($ast, $assignments, $outDir)

        $usedNames = Get-UsedScriptBlockNamesFromUpdateTypeData $ast
        if (-not $usedNames) {
            Write-Host "ℹ️ Update-TypeData に渡された ScriptBlock 変数が見つかりません。"
            return
        }

        $usedAssignments = FilterUsedScriptBlocks $assignments $usedNames

        $updateCalls = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.CommandElements[0].Value -eq 'Update-TypeData'
            }, $true)

        $extensionLines = @()

        foreach ($assign in $usedAssignments) {
            $extensionLines += $assign.Extent.Text
        }

        foreach ($call in $updateCalls) {
            $elements = $call.CommandElements
            for ($i = 0; $i -lt $elements.Count - 1; $i++) {
                if ($elements[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and
                    $elements[$i].ParameterName -eq 'Value' -and
                    $elements[$i + 1] -is [System.Management.Automation.Language.VariableExpressionAst]) {

                    $varName = $elements[$i + 1].VariablePath.UserPath
                    if ($varName -in $usedNames) {
                        $extensionLines += $call.Extent.Text
                    }
                }
            }
        }

        # 未定義な使用を警告
        $definedNames = $assignments | ForEach-Object { $_.Left.VariablePath.UserPath }
        $undefined = $usedNames | Where-Object { $_ -notin $definedNames }

        foreach ($name in $undefined) {
            Write-Warning "⚠️ '$$${name}' は Update-TypeData で使用されていますが、ScriptBlock 定義が見つかりません。"
        }

        if ($extensionLines.Count -gt 0) {
            $extPath = Join-Path $outDir "Extensions\System.DateTime.Extension.ps1"
            New-Item -ItemType Directory -Path (Split-Path $extPath) -Force | Out-Null
            Set-Content -Path $extPath -Value ($extensionLines -join "`r`n`r`n") -Encoding UTF8
            Write-Host "🧠 型拡張分割: 使用中の ScriptBlock のみ → Extensions/"
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
    Split-TypeExtension $rootAst $assignments $outRoot
    
    Write-Host "✅ 分割完了: $SourcePath → $outRoot"
}