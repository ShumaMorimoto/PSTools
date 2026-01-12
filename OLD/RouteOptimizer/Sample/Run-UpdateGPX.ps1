param (
    [string]$InputFolder = "D:\tool\GPX\Input",
    [string]$OutputFolder = "D:\tool\GPX\Output",
    [switch]$ForceUpdate
)

# フォルダ内のGPXファイルを列挙
$files = Get-ChildItem -Path $InputFolder -Filter *.gpx

$processed = 0
$updated   = 0
$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($file in $files) {
    $processed++

    $outPath = Join-Path $OutputFolder ($file.BaseName + ".updated.gpx")

    # 差分更新: 既に更新済みならスキップ
    if (-not $ForceUpdate -and (Test-Path $outPath)) {
        Write-Host "⏭ スキップ: $outPath は既に存在"
        continue
    }

    try {
        # 呼び出し側から Update-PlaceInfoGPX.ps1 を実行
        & "$PSScriptRoot\Update-PlaceInfoGPX.ps1" `
            -InputGpxPath $file.FullName `
            -OutputGpxPath $outPath `
            -ForceUpdate

        $updated++
    }
    catch {
        Write-Error "❌ 処理失敗: $($file.FullName) → $($_.Exception.Message)"
    }
}

$sw.Stop()
Write-Host ("📊 完了: 総ファイル={0}, 更新={1}, 時間={2}ms" -f $processed, $updated, $sw.ElapsedMilliseconds) -ForegroundColor Cyan