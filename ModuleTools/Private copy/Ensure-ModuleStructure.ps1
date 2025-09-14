function Ensure-ModuleStructure {
    param (
        [string]$RootPath
    )

    if (-not $script:TemplatesPath) {
        throw "❌ $script:TemplatesPath が定義されていません。"
    }

    $structurePath = Join-Path $script:TemplatesPath 'ModuleStructure.template.json'
    if (-not (Test-Path $structurePath)) {
        throw "❌ テンプレートファイルが見つかりません: $structurePath"
    }

    $structure = Get-Content $structurePath | ConvertFrom-Json
    $folders = $structure.Folders

    foreach ($folder in $folders) {
        $path = Join-Path $RootPath $folder
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
            Write-Host "📁 フォルダ作成: $folder"
        }
    }
}