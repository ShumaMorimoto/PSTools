function Get-ExcelRegPath {
    $officeVersions = @("16.0", "15.0", "14.0")
    foreach ($ver in $officeVersions) {
        $path = "HKCU:\Software\Microsoft\Office\$ver\Excel\Options"
        if (Test-Path $path) {
            Write-Host "✅ Excelバージョン $ver を検出"
            return $path
        }
    }
    throw "❌ Excelのレジストリキーが見つかりません"
}

function Inject-RibbonXmlToXlam {
    param (
        [string]$addinPath,
        [string]$customUIPath,
        [string]$outputPath
    )

    $tempFolder = "$env:TEMP\addin_edit"
    Remove-Item -Recurse -Force $tempFolder -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $tempFolder | Out-Null

    Copy-Item $addinPath "$tempFolder\addin.zip"
    Expand-Archive "$tempFolder\addin.zip" "$tempFolder\unzipped"

    $uiFolder = "$tempFolder\unzipped\customUI"
    New-Item -ItemType Directory -Path $uiFolder -Force | Out-Null
    Copy-Item $customUIPath "$uiFolder\customUI.xml"

    $modifiedZip = "$tempFolder\modified.zip"
    Compress-Archive "$tempFolder\unzipped\*" $modifiedZip -Force
    Copy-Item $modifiedZip $outputPath -Force

    Write-Host "✅ リボンXMLを '$outputPath' に埋め込み完了"
}

function Register-AddinToExcel {
    param (
        [string]$addinPath,
        [string]$regPath
    )

    $quotedPath = '"' + (Resolve-Path $addinPath).Path + '"'

    $existing = Get-ItemProperty -Path $regPath | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -like "OPEN*" }
    $nextIndex = ($existing.Name | ForEach-Object { $_ -replace "OPEN", "" } | Sort-Object | Select-Object -Last 1)
    $nextIndex = if ($nextIndex) { [int]$nextIndex + 1 } else { 1 }

    Set-ItemProperty -Path $regPath -Name "OPEN$nextIndex" -Value $quotedPath
    Write-Host "✅ アドイン登録完了（OPEN$nextIndex） → $quotedPath"
}

# === 実行例 ===
$addinPath = ".\custom.xlam"
$customUIPath = ".\customUI.xml"
$outputPath = ".\custom2.xlam"

$regPath = Get-ExcelRegPath
Inject-RibbonXmlToXlam -addinPath $addinPath -customUIPath $customUIPath -outputPath $outputPath
Register-AddinToExcel -addinPath $outputPath -regPath $regPath
