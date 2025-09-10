param (
    [Parameter(Mandatory)]
    [string]$SourcePath
)

function Ensure-Directory {
    param ($path)
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

function Split-Class {
    param ($classAst, $outDir)
    $className = $classAst.Name
    $code = $classAst.Extent.Text
    $outPath = Join-Path $outDir "Classes\$className.ps1"
    Set-Content -Path $outPath -Value $code
    Write-Host "🧩 クラス分割: $className → Classes/"
}

function Split-Function {
    param ($funcAst, $isExported, $outDir)
    $funcName = $funcAst.Name
    $folder = if ($isExported) { "Public" } else { "Private" }
    $code = $funcAst.Extent.Text
    $outPath = Join-Path $outDir "$folder\$funcName.ps1"
    Set-Content -Path $outPath -Value $code
    Write-Host "🔧 関数分割: $funcName → $folder/"
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

# 🔍 入力ファイル確認とモジュール名取得
if (-not (Test-Path $SourcePath)) {
    throw "❌ ファイルが存在しません: $SourcePath"
}
$resolved = Resolve-Path -Path $SourcePath
$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($resolved.ProviderPath)
$outRoot = Join-Path (Get-Location) $moduleName

# 📁 出力ディレクトリ準備
@("Classes", "Public", "Private") | ForEach-Object {
    Ensure-Directory (Join-Path $outRoot $_)
}

# 🔍 AST解析
$rootAst = [System.Management.Automation.Language.Parser]::ParseFile($resolved.ProviderPath, [ref]$null, [ref]$null)
if (-not $rootAst) {
    throw "❌ ASTの解析に失敗しました。構文エラーの可能性があります。"
}

# 📤 Export対象関数抽出
$exported = Get-ExportedFunctions $rootAst
Write-Host "📤 Export対象関数: $($exported -join ', ')"

# 🧩 クラス分割（明示的 param スタイル）
$rootAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.TypeDefinitionAst]
}, $true) | ForEach-Object {
    Split-Class $_ $outRoot
}

# 🔧 関数分割（トップレベル関数のみ）
$rootAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    -not ($node.Parent -and $node.Parent.Parent -is [System.Management.Automation.Language.TypeDefinitionAst])
}, $true) | ForEach-Object {
    $isExported = $exported -contains $_.Name
    Split-Function $_ $isExported $outRoot
}

Write-Host "✅ 分割完了: $SourcePath → $outRoot"