function Get-ClassDependencyTree {
    param (
        [string]$ModuleRoot = (Get-Location).Path,
        [string]$ClassName
    )

    if (-not $ClassName) {
        throw "❌ クラス名を指定してください。"
    }

    $classesPath = Join-Path $ModuleRoot "Classes"
    $psm1Path    = Join-Path $ModuleRoot "$((Split-Path $ModuleRoot -Leaf)).psm1"

    if (-not (Test-Path $psm1Path)) {
        throw "❌ モジュールの .psm1 ファイルが見つかりません: $psm1Path"
    }

    # 🔍 AST解析
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($psm1Path, [ref]$null, [ref]$null)
    $classDefs = $ast.FindAll({ $_ -is [System.Management.Automation.Language.TypeDefinitionAst] }, $true)

    # クラス名 → AST のマップ
    $classMap = @{}
    foreach ($class in $classDefs) {
        $classMap[$class.Name] = $class
    }

    if (-not $classMap.ContainsKey($ClassName)) {
        throw "❌ 指定されたクラス '$ClassName' は .psm1 に定義されていません。"
    }

    # 再帰的に依存クラスを抽出
    $visited = @{}
    $dependencies = @()

    function Visit($name) {
        if ($visited[$name]) { return }
        $visited[$name] = $true

        $classAst = $classMap[$name]
        if (-not $classAst) { return }

        # 継承元
        foreach ($base in $classAst.BaseTypes) {
            $baseName = $base.TypeName.Name
            if ($classMap.ContainsKey($baseName)) {
                Visit $baseName
            }
        }

        # 使用型（フィールド・戻り値・引数・インスタンス化）
        $usedTypes = $classAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.TypeExpressionAst]
        }, $true) | ForEach-Object { $_.TypeName.Name }

        foreach ($type in $usedTypes) {
            if ($classMap.ContainsKey($type)) {
                Visit $type
            }
        }

        $dependencies += $name
    }

    Visit $ClassName

    # 📤 出力（依存順）
    $dependencies | ForEach-Object { Write-Output $_ }
}