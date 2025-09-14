function New-ModuleScaffold {
    param ([string]$ModuleName)

    $outRoot = Join-Path (Get-Location) $ModuleName
    Ensure-ModuleStructure -RootPath $outRoot
    Write-Host "✅ モジュール雛形 '$ModuleName' を初期化しました。"
}