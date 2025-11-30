using module RouteOptimizer

param (
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath,

    [Parameter()]
    [switch]$ForceUpdate
)
process {
    try {
        # 出力パスが未指定なら自動生成
        if (-not $OutputGpxPath) {
            $OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.updated.gpx')"
        }

        # ① GPX読み込み
        $gpxDoc = [GPXDocument]::Load($InputGpxPath)

        # ② 拠点情報付加（ForceUpdateスイッチで上書き制御）
        $gpxDoc = [GPXDocumentFactory]::EnrichTrkPts($gpxDoc, $ForceUpdate)

        # ③ 保存
        $gpxDoc.Save($OutputGpxPath)
        Write-Host "✅ 更新完了: $OutputGpxPath" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ GPX処理失敗 ($InputGpxPath): $($_.Exception.Message)"
    }
}