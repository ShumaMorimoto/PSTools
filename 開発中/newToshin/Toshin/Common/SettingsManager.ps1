function Write-ModuleSettings {
    $script:ModuleSettings.LastUpdated = (Get-Date).ToString('o')
    $script:ModuleSettings | ConvertTo-Json -Depth 10 | Set-Content $script:SettingsPath
}

function Enable-ModuleSettings {
    # モジュール名を取得（psm1ファイル名から）
    $moduleName = Split-Path -Leaf $script:ModuleRoot
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($moduleName)

   # 動的にサブフォルダのパスを定義
    $subFolders = Get-ChildItem -Path $script:ModuleRoot -Directory
    foreach ($folder in $subFolders) {
        $name = $folder.Name
        $varName = "${name}Path"
        Set-Variable -Name $varName -Value $folder.FullName -Scope Script 
    }

    # 設定ファイルパスを構築
    $settingsDir = Join-Path $env:ProgramData $moduleName
    $script:SettingsPath = Join-Path $settingsDir 'Settings.json'

    # ディレクトリ作成
    if (-not (Test-Path $settingsDir)) {
        New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
    }

    # 設定ファイルの生成 or 読み込み
    if (-not (Test-Path $script:SettingsPath)) {
        $defaultPath = Join-Path $script:ModuleRoot 'Templates\DefaultSettings.json'
        $defaultSettings = Get-Content $defaultPath -Raw | ConvertFrom-Json -AsHashtable
        
        Write-ModuleSettings -SettingsObject $defaultSettings
        $script:ModuleSettings = $defaultSettings
    } else {
        $script:ModuleSettings = Get-Content $script:SettingsPath -Raw | ConvertFrom-Json
    }
}