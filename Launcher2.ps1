param(
    [Parameter(Position = 0, HelpMessage = "ScriptDefinition が書かれた JSON ファイルのパス")]
    [string]$DefinitionsFile = "$PSScriptRoot\scriptDefs.json"
)

# 必要なアセンブリをロード
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
}
catch {
    Write-Error "Windows Forms / Drawing のロードに失敗しました: $($_.Exception.Message)"
    exit 1
}

# JSON 読み込み
if (-not (Test-Path -LiteralPath $DefinitionsFile)) {
    [System.Windows.Forms.MessageBox]::Show(
        "定義ファイルが見つかりません。`n$DefinitionsFile",
        "エラー",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

try {
    $ScriptDefinitions = Get-Content -LiteralPath $DefinitionsFile -Raw | ConvertFrom-Json
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "定義ファイルの読み込み／パースに失敗しました。`n$DefinitionsFile`n$($_.Exception.Message)",
        "エラー",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

# 高DPI対応（PowerShell 7+）
if ([Environment]::OSVersion.Version.Major -ge 6) {
    [System.Windows.Forms.Application]::SetHighDpiMode('SystemAware')
    [System.Windows.Forms.Application]::EnableVisualStyles()
}

# フォーム作成
$form = [System.Windows.Forms.Form]@{
    Text            = "PowerShell Script Launcher"
    Size            = [System.Drawing.Size]::new(600, 520)
    StartPosition   = "CenterScreen"
    Font            = [System.Drawing.Font]::new("Yu Gothic UI", 10)
    FormBorderStyle = "FixedDialog"
    MaximizeBox     = $false
}

# コンテナ
$container = [System.Windows.Forms.Panel]@{ Dock = 'Fill'; Padding = [System.Windows.Forms.Padding]::new(10) }
$form.Controls.Add($container)

# メニュー（タイル）
$menuPanel = [System.Windows.Forms.FlowLayoutPanel]@{
    Dock = 'Fill'; FlowDirection = 'LeftToRight'; AutoScroll = $true
}
$container.Controls.Add($menuPanel)

# 詳細画面
$detailPanel = [System.Windows.Forms.Panel]@{ Dock = 'Fill'; Visible = $false }
$container.Controls.Add($detailPanel)

# 詳細構成
$detailHeader = [System.Windows.Forms.Label]@{ Dock = 'Top'; Height = 40; Font = [System.Drawing.Font]::new("Yu Gothic UI", 14, [System.Drawing.FontStyle]::Bold); TextAlign = 'MiddleLeft' }
$detailDesc = [System.Windows.Forms.Label]@{ Dock = 'Top'; Height = 40; ForeColor = [System.Drawing.Color]::Gray; TextAlign = 'MiddleLeft' }
$detailInputs = [System.Windows.Forms.FlowLayoutPanel]@{ Dock = 'Fill'; FlowDirection = 'TopDown'; AutoScroll = $true; Padding = [System.Windows.Forms.Padding]::new(0, 10, 0, 0) }
$detailFooter = [System.Windows.Forms.FlowLayoutPanel]@{ Dock = 'Bottom'; Height = 60; FlowDirection = 'RightToLeft' }

$btnBack = [System.Windows.Forms.Button]@{ Text = '戻る'; Width = 100; Height = 40; Margin = [System.Windows.Forms.Padding]::new(10, 5, 0, 5) }
$btnRun = [System.Windows.Forms.Button]@{ Text = '実行'; Width = 150; Height = 40; BackColor = [System.Drawing.Color]::DodgerBlue; ForeColor = [System.Drawing.Color]::White; Font = [System.Drawing.Font]::new("Yu Gothic UI", 11, [System.Drawing.FontStyle]::Bold); Margin = [System.Windows.Forms.Padding]::new(5) }

$detailFooter.Controls.Add($btnRun)
$detailFooter.Controls.Add($btnBack)

$detailPanel.Controls.Add($detailInputs)
$detailPanel.Controls.Add($detailDesc)
$detailPanel.Controls.Add($detailHeader)
$detailPanel.Controls.Add($detailFooter)

# 現在選択中のスクリプトと入力コントロールを保持
$currentDef = $null
$currentInputControls = @{}

# メニュー構築
function Build-Menu {
    $menuPanel.Controls.Clear()

    foreach ($def in $ScriptDefinitions) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $def.Name
        $btn.Width = 180
        $btn.Height = 100
        try {
            $btn.BackColor = [System.Drawing.Color]::FromName($def.Color)
            $btn.ForeColor = [System.Drawing.Color]::White
        }
        catch {
            $btn.BackColor = [System.Drawing.Color]::LightGray
            $btn.ForeColor = [System.Drawing.Color]::Black
        }
        $btn.Font = [System.Drawing.Font]::new("Yu Gothic UI", 12, [System.Drawing.FontStyle]::Bold)
        $btn.FlatStyle = 'Flat'
        $btn.Margin = [System.Windows.Forms.Padding]::new(5)
        $btn.FlatAppearance.BorderSize = 0

        # Tag にオブジェクト丸ごと詰めておく
        $btn.Tag = $def

        # イベントハンドラ
        $btn.Add_Click( {
                param($sender, $e)
                Show-Detail $sender.Tag
            })

        $menuPanel.Controls.Add($btn)
    }
}

# 詳細表示
function Show-Detail($def) {
    $script:currentDef = $def
    $script:currentInputControls.Clear()

    $detailHeader.Text = $def.Name
    try {
        $detailHeader.ForeColor = if ($def.Color) { [System.Drawing.Color]::FromName($def.Color) } else { [System.Drawing.Color]::Black }
    }
    catch {
        $detailHeader.ForeColor = [System.Drawing.Color]::Black
    }
    $detailDesc.Text = $def.Description

    $detailInputs.Controls.Clear()

    if ($def.Params) {
        foreach ($p in $def.Params) {
            $pName = $p.Name
            $pLabel = if ($p.Label) { $p.Label } else { $p.Name }
            $pType = $p.Type
            $pDefault = if ($p.Default) { $p.Default } else { "" }

            # ラベル
            $l = New-Object System.Windows.Forms.Label
            $l.Text = $pLabel
            $l.AutoSize = $true
            $l.Margin = [System.Windows.Forms.Padding]::new(0, 5, 0, 0)
            $detailInputs.Controls.Add($l)

            $inputContainer = New-Object System.Windows.Forms.FlowLayoutPanel
            $inputContainer.Width = 540
            $inputContainer.Height = 35
            $inputContainer.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 10)
            $inputContainer.FlowDirection = 'LeftToRight'
            $inputContainer.WrapContents = $false

            switch ($pType) {
                'File' {
                    $txt = New-Object System.Windows.Forms.TextBox
                    $txt.Width = 400
                    $txt.Text = $pDefault
                    $txt.Font = [System.Drawing.Font]::new("Consolas", 10)
                    $btnBrowse = New-Object System.Windows.Forms.Button
                    $btnBrowse.Text = '...'
                    $btnBrowse.Width = 40
                    $btnBrowse.Height = 25

                    $btnBrowse.Add_Click({
                            $dlg = New-Object System.Windows.Forms.OpenFileDialog
                            if ($p.Filter) { $dlg.Filter = $p.Filter }
                            if (-not [string]::IsNullOrWhiteSpace($txt.Text)) {
                                try { $dlg.InitialDirectory = [System.IO.Path]::GetDirectoryName($txt.Text) } catch {}
                            }
                            if ($dlg.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
                                $txt.Text = $dlg.FileName
                            }
                        })

                    $inputContainer.Controls.Add($txt)
                    $inputContainer.Controls.Add($btnBrowse)
                    $currentInputControls[$pName] = $txt
                }
                'Int' {
                    $nud = New-Object System.Windows.Forms.NumericUpDown
                    $nud.Width = 120
                    $nud.Minimum = 0
                    $nud.Maximum = 100000000
                    try { $nud.Value = [decimal]$pDefault } catch {}
                    $inputContainer.Controls.Add($nud)
                    $currentInputControls[$pName] = $nud
                }
                'Double' {
                    $txt = New-Object System.Windows.Forms.TextBox
                    $txt.Width = 120
                    $txt.Text = $pDefault
                    $txt.Font = [System.Drawing.Font]::new("Consolas", 10)
                    $inputContainer.Controls.Add($txt)
                    $currentInputControls[$pName] = $txt
                }
                default {
                    $txt = New-Object System.Windows.Forms.TextBox
                    $txt.Width = 500
                    $txt.Text = $pDefault
                    $txt.Font = [System.Drawing.Font]::new("Consolas", 10)
                    $inputContainer.Controls.Add($txt)
                    $currentInputControls[$pName] = $txt
                }
            }

            $detailInputs.Controls.Add($inputContainer)
        }
    }
    else {
        $lblNone = New-Object System.Windows.Forms.Label
        $lblNone.Text = "パラメータはありません。このまま実行できます。"
        $lblNone.AutoSize = $true
        $lblNone.ForeColor = [System.Drawing.Color]::Gray
        $detailInputs.Controls.Add($lblNone)
    }

    $menuPanel.Visible = $false
    $detailPanel.Visible = $true
}

# 戻る
$btnBack.Add_Click({
        $detailPanel.Visible = $false
        $menuPanel.Visible = $true
    })

# 実行
$btnRun.Add_Click({
        $def = $script:currentDef
        if (-not $def) { return }

        # スクリプトパス（ランチャーと同じフォルダにある前提）
        $scriptFullPath = $def.ScriptPath

        if (-not (Test-Path $scriptFullPath)) {
            [System.Windows.Forms.MessageBox]::Show(
                "スクリプトファイルが見つかりません。`n$scriptFullPath",
                "エラー",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }

        $argsList = @()
        foreach ($key in $currentInputControls.Keys) {
            $ctrl = $currentInputControls[$key]
            $val = switch ($ctrl.GetType().Name) {
                "NumericUpDown" { $ctrl.Value.ToString() }
                default { $ctrl.Text }
            }

            if ([string]::IsNullOrWhiteSpace($val)) { continue }

            $paramMeta = $def.Params | Where-Object { $_.Name -eq $key }
            $type = if ($paramMeta) { $paramMeta.Type } else { "String" }

            $argsList += "-$key"
            if ($type -eq "String" -or $type -eq "File") {
                $escaped = $val -replace '"', '\"'
                $argsList += "`"$escaped`""
            }
            else {
                $argsList += $val
            }
        }

        $argString = $argsList -join " "

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "pwsh"
        $processInfo.Arguments = "-NoProfile -NoExit -Command & '$scriptFullPath' $argString"
        $processInfo.UseShellExecute = $true

        try {
            [System.Diagnostics.Process]::Start($processInfo) | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "実行失敗: $($_.Exception.Message)",
                "エラー",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

# 初期化・起動
Build-Menu
$form.ShowDialog() | Out-Null
$form.Dispose()
