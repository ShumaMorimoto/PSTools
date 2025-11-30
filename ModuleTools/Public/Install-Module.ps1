function Install-Module {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir   # モジュールのトップディレクトリ (例: D:\TOOL\REPOSITORY\PSTOOLS\ROUTEOPTIMIZER)
    )

    # モジュール名はフォルダ名から決定
    $resolvedSource = Resolve-Path $SourceDir
    $ModuleName = Split-Path $resolvedSource -Leaf

    $targetRoot = "C:\Program Files\WindowsPowerShell\Modules"
    $targetPath = Join-Path $targetRoot $ModuleName

    Write-Host "🔍 差分を確認中 (モジュール名: $ModuleName)..." -ForegroundColor Cyan
    if (Test-Path $targetPath) {
        Compare-ModuleFolders -SourceDir $resolvedSource -TargetDir $targetPath
    }
    else {
        Write-Host "⚠️ ターゲットにモジュールが存在しません。新規インストールになります。" -ForegroundColor Yellow
    }

    $answer = Read-Host "👉 この差分を反映してインストールしますか？ (Y/N)"
    if ($answer -match '^[Yy]$') {
        if (Test-Path $targetPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = "${targetPath}_backup_$timestamp"
            Rename-Item -Path $targetPath -NewName $backupPath
            Write-Host "📦 既存モジュールをバックアップしました: $backupPath" -ForegroundColor Yellow
        }

        Copy-Item $resolvedSource $targetPath -Recurse -Force
        Write-Host "✅ モジュール $ModuleName をインストールしました。" -ForegroundColor Green
    }
    else {
        Write-Host "🚫 インストールをキャンセルしました。" -ForegroundColor Red
    }
}