function Initialize-ModuleFromPsm1 {
    param (
        [string]$SourcePath,
        [string]$Author = 'YourName',
        [string]$Description = 'Auto-generated module project.'
    )

    # ─── 事前準備 ───
    if (-not $SourcePath) {
        $psm1File = Get-ChildItem -Path (Get-Location) -Filter *.psm1 | Select-Object -First 1
        if (-not $psm1File) { throw "❌ .psm1 ファイルが見つかりません。" }
        $SourcePath = $psm1File.FullName
    } else {
        $SourcePath = Resolve-Path $SourcePath
    }
    if (-not (Test-Path $SourcePath)) {
        throw "❌ ファイルが存在しません: $SourcePath"
    }

    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
    $moduleRoot = Join-Path (Get-Location) $moduleName
    $structureTemplatePath = Join-Path $script:TemplatesPath 'ModuleStructure.template.json'

    # ─── フォルダ構成作成 ───
    $structure = Get-Content $structureTemplatePath | ConvertFrom-Json
    foreach ($folder in $structure.Folders) {
        $path = Join-Path $moduleRoot $folder
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
            Write-Host "📁 フォルダ作成: $folder"
        }
    }

    # ─── AST解析 ───
    $resolved = Resolve-Path -Path $SourcePath
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($resolved.ProviderPath, [ref]$null, [ref]$null)
    if (-not $ast) { throw "❌ AST解析に失敗しました。" }

    $exported = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] -and $args[0].CommandElements[0].Value -eq 'Export-ModuleMember' }, $true) |
    ForEach-Object { $_.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } | ForEach-Object { $_.Value } }

    # ─── クラス分割 ───
    $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.TypeDefinitionAst] }, $true) |
    ForEach-Object {
        $name = $_.Name
        $code = $_.Extent.Text
        Set-Content -Path (Join-Path $moduleRoot "Classes\$name.ps1") -Value $code -Encoding UTF8
        Write-Host "🧩 クラス分割: $name"
    }

    # ─── 関数分割 ───
    $ast.FindAll( { param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            -not ($node.Parent -and $node.Parent.Parent -is [System.Management.Automation.Language.TypeDefinitionAst])
        }, $true) | 
    ForEach-Object {
        $name = $_.Name
        $code = $_.Extent.Text
        $folder = if ($exported -contains $name) { "Public" } else { "Private" }
        Set-Content -Path (Join-Path $moduleRoot "$folder\$name.ps1") -Value $code -Encoding UTF8
        Write-Host "🔧 関数分割: $name → $folder"
    }

    # ─── 型拡張分割（複数型対応） ───
    # 1. ScriptBlock の変数定義を抽出
    $assignments = $Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Right.Find({ $args[0] -is [System.Management.Automation.Language.ScriptBlockAst] }, $true)
        }, $true)

    # 2. Update-TypeData 呼び出しを抽出
    $updateCalls = $Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.CommandElements[0].Value -eq 'Update-TypeData'
        }, $true)

    # 3. 型ごとに使用されている ScriptBlock 変数をマッピング
    $typeMap = @{}

    foreach ($call in $updateCalls) {
        $elements = $call.CommandElements
        $typeName = $null
        $valueName = $null

        for ($i = 0; $i -lt $elements.Count - 1; $i++) {
            $current = $elements[$i]
            $next = $elements[$i + 1]

            if ($current -is [System.Management.Automation.Language.CommandParameterAst]) {
                switch ($current.ParameterName) {
                    'TypeName' {
                        $typeName = $next.Value
                    }
                    'Value' {
                        if ($next -is [System.Management.Automation.Language.VariableExpressionAst]) {
                            $valueName = $next.VariablePath.UserPath
                        }
                    }
                }
            }
        }

        if ($typeName -and $valueName) {
            if (-not $typeMap.ContainsKey($typeName)) {
                $typeMap[$typeName] = @()
            }
            $typeMap[$typeName] += @{
                ValueName = $valueName
                Call      = $call
            }
        }
    }

    # 4. 型ごとにファイル出力
    foreach ($typeName in $typeMap.Keys) {
        $lines = @()
        $valueNames = $typeMap[$typeName] | ForEach-Object { $_.ValueName }

        $usedAssignments = $assignments | Where-Object {
            $valueNames -contains $_.Left.VariablePath.UserPath
        }
        foreach ($assign in $usedAssignments) { $lines += $assign.Extent.Text }
        foreach ($entry in $typeMap[$typeName]) { $lines += $entry.Call.Extent.Text }

        $safeName = $typeName -replace '[^a-zA-Z0-9\.]', '_'
        $extPath = Join-Path $moduleRoot "Extensions\$safeName.Extension.ps1"
        Set-Content -Path $extPath -Value ($lines -join "`r`n`r`n") -Encoding UTF8
        Write-Host "🧠 型拡張分割: $typeName → Extensions/"
    }
    
    # ─── テンプレートコピー ───
    foreach ($file in @('Module.psm1.template', 'Module.psd1.template')) {
        $source = Join-Path $script:TemplatesPath $file
        $target = Join-Path $moduleRoot "Templates\$file"
        Copy-Item -Path $source -Destination $target -Force
        Write-Host "📄 テンプレートコピー: $file"
    }

    # ─── 共通関数コピー ───
    $targetCommon = Join-Path $moduleRoot 'Common'
    if (Test-Path $script:CommonPath) {
        Get-ChildItem -Path $script:CommonPath -Filter *.ps1 -File | ForEach-Object {
            $target = Join-Path $targetCommon $_.Name
            Copy-Item -Path $_.FullName -Destination $target -Force
            Write-Host "🔁 共通関数コピー: $($_.Name) → Common/"
        }
    }
    else {
        Write-Warning "⚠️ 共通関数フォルダが見つかりません: $script:CommonPath"
    }

    Write-Host "✅ モジュール初期化完了: $moduleName"
}