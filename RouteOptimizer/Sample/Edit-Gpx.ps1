using module D:\tool\Repository\PSTools\RouteOptimizer

param (
    [Parameter()]
    [string]$InputPath = $null,
    [Parameter()]
    [string]$OutputPath = $null
)

if ($InputPath) {
    $gpxXml = [GPXDocument]::Load($InputPath)
    $OutputPath = (Get-OutputFilename $InputPath 'edited')
}
else {
    $gpxXml = $null
    $OutputPath = (Join-Path -Path $PWD -ChildPath "MapEdited.gpx")
}

$newGpxXml = [GPXDocumentFactory]::FromMapEdit($gpxXml)

# ④ ファイルに保存
try {
    $newGpxXml.Save($OutputPath)
    Write-Host "✅ GPXファイルを保存しました: $OutputPath" -ForegroundColor Green
}
catch {
    Write-Error "❌ GPXファイルの保存に失敗しました: $($_.Exception.Message)"
}
