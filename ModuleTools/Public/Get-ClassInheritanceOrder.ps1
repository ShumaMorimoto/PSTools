function Get-ClassInheritanceOrder {
    param (
        [string]$ClassesPath
    )

    # ─── クラスファイルの取得 ───
    $files = Get-ChildItem -Path $ClassesPath -Filter *.ps1
    $classMap = @{}         # クラス名 → ファイルパス
    $baseTypeMap = @{}      # クラス名 → 親クラス名の配列

    # ─── クラス名と親クラスを抽出 ───
    foreach ($file in $files) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
        $classAst = $ast.Find({ $args[0] -is [System.Management.Automation.Language.TypeDefinitionAst] }, $true)

        if ($classAst) {
            $className = $classAst.Name
            $baseTypes = $classAst.BaseTypes | ForEach-Object { $_.TypeName.FullName }

            $classMap[$className] = $file.FullName
            $baseTypeMap[$className] = $baseTypes
        }
    }

    # ─── 依存関係グラフの構築 ───
    $dependencyMap = @{}
    foreach ($className in $classMap.Keys) {
        $dependencyMap[$className] = $baseTypeMap[$className] | Where-Object { $classMap.ContainsKey($_) }
    }

    # ─── トポロジカルソート ───
    $visited = @{}
    $script:result = @()

    function Visit($node) {
        if ($visited[$node] -eq 'temp') {
            throw "❌ 循環継承が検出されました: $node"
        }
        if (-not $visited.ContainsKey($node)) {
            $visited[$node] = 'temp'
            foreach ($dep in $dependencyMap[$node]) {
                Visit $dep
            }
            $visited[$node] = 'perm'
            $script:result += $node
        }
    }

    foreach ($node in $dependencyMap.Keys) {
        Visit $node
    }

    # ─── ファイルパス順に変換して返す ───
    return $script:result | ForEach-Object { $classMap[$_] }
}