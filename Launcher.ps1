# -----------------------------------------------------------------------------
# PowerShell 7 用 タイル型スクリプトランチャー
# -----------------------------------------------------------------------------
using namespace System.Windows.Forms
using namespace System.Drawing

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =============================================================================
# ▼ 設定エリア：ここにスクリプトとパラメータを定義してください ▼
# =============================================================================
$ScriptDefinitions = @(
    @{
        Name        = "GPXルート分割"
        ScriptPath  = "Split-Gpx.ps1"
        Description = "距離やポイント数でGPXファイルを分割します。"
        Color       = "MediumSeaGreen"  # タイルの色
        Params      = @(
            @{ Name = "InputFile"; Type = "File"; Label = "入力GPXファイル (*.gpx)"; Filter = "GPX Files|*.gpx|All Files|*.*" },
            @{ Name = "DistanceKm"; Type = "Double"; Label = "分割距離 (km) (0=無効)"; Default = "0.0" },
            @{ Name = "PointLimit"; Type = "Int"; Label = "ポイント数制限 (0=無効)"; Default = "40" }
        )
    },
    @{
        Name        = "ログ解析ツール"
        ScriptPath  = "Analyze-Logs.ps1"
        Description = "サーバーのログファイルを解析してレポートを出力します。"
        Color       = "SteelBlue"
        Params      = @(
            @{ Name = "LogDir"; Type = "String"; Label = "ログフォルダパス"; Default = "C:\Logs" },
            @{ Name = "Days"; Type = "Int"; Label = "対象日数"; Default = "7" }
        )
    },
    @{
        Name        = "データバックアップ"
        ScriptPath  = "Backup-Data.ps1"
        Description = "指定フォルダをZIP圧縮して退避します。"
        Color       = "IndianRed"
        Params      = @(
            @{ Name = "Source"; Type = "String"; Label = "バックアップ元"; Default = "D:\Data" },
            @{ Name = "Dest"; Type = "String"; Label = "保存先"; Default = "Z:\Backup" }
        )
    }
)
# =============================================================================
# ▲ 設定エリア終了 ▲
# =============================================================================

# 高DPI対応
if ([Environment]::OSVersion.Version.Major -ge 6) {
    [System.Windows.Forms.Application]::SetHighDpiMode('SystemAware') 
    [System.Windows.Forms.Application]::EnableVisualStyles()
}

# --- フォーム設定 ---
$form = [Form]@{
    Text            = "PowerShell Script Launcher"
    Size            = [Size]::new(600, 500)
    StartPosition   = "CenterScreen"
    Font            = [Font]::new("Yu Gothic UI", 10)
    FormBorderStyle = "FixedDialog"
    MaximizeBox     = $false
}

# メインパネル（ページ切り替え用）
$container = [Panel]@{ Dock = "Fill"; Padding = [Padding]::new(10) }
$form.Controls.Add($container)

# --- ページ1: メニュー画面 (タイル一覧) ---
$menuPanel = [FlowLayoutPanel]@{
    Dock          = "Fill"
    FlowDirection = "LeftToRight"
    AutoScroll    = $true
    Visible       = $true
}
$container.Controls.Add($menuPanel)

# --- ページ2: パラメータ入力画面 ---
$detailPanel = [Panel]@{
    Dock    = "Fill"
    Visible = $false
}
$container.Controls.Add($detailPanel)

# 詳細画面のレイアウト
$detailHeader = [Label]@{
    Dock      = "Top"
    Height    = 40
    Font      = [Font]::new("Yu Gothic UI", 14, [FontStyle]::Bold)
    TextAlign = "MiddleLeft"
}
$detailDesc = [Label]@{
    Dock      = "Top"
    Height    = 40
    ForeColor = [Color]::Gray
    TextAlign = "MiddleLeft"
}
$detailInputs = [FlowLayoutPanel]@{
    Dock          = "Fill"
    FlowDirection = "TopDown"
    AutoScroll    = $true
    Padding       = [Padding]::new(0, 10, 0, 0)
}
$detailFooter = [FlowLayoutPanel]@{
    Dock          = "Bottom"
    Height        = 50
    FlowDirection = "RightToLeft" # ボタンを右寄せ
}

# 詳細画面にコントロール追加
$detailPanel.Controls.Add($detailInputs)
$detailPanel.Controls.Add($detailDesc) # 上から順にドッキングされるので注意（逆順に追加したり調整が必要だがPanelならOK）
$detailPanel.Controls.Add($detailHeader)
$detailPanel.Controls.Add($detailFooter)
# ※Dock=Topは最後に追加したものが一番上に来るため、Headerを最後に追加するのが正解だが、ここではControls.SetChildIndexで調整も可。
# 簡易的に、Top要素は下から順に追加する。
$detailPanel.Controls.Clear()
$detailPanel.Controls.Add($detailInputs) # Fill
$detailPanel.Controls.Add($detailDesc)   # Top (2番目)
$detailPanel.Controls.Add($detailHeader) # Top (1番目)
$detailPanel.Controls.Add($detailFooter) # Bottom

# 戻るボタン・実行ボタン
$btnBack = [Button]@{ Text = "戻る"; Width = 100; Height = 40; Margin = [Padding]::new(10,5,0,5) }
$btnRun  = [Button]@{ Text = "実行"; Width = 150; Height = 40; BackColor = [Color]::DodgerBlue; ForeColor = [Color]::White; Font = [Font]::new("Yu Gothic UI", 11, [FontStyle]::Bold); Margin = [Padding]::new(5) }

$detailFooter.Controls.Add($btnRun)
$detailFooter.Controls.Add($btnBack)

# 現在選択中のスクリプト定義と入力コントロール保持用
$currentDef = $null
$currentInputControls = @{} 

# --- 関数: メニュー画面構築 ---
function Build-Menu {
    $menuPanel.Controls.Clear()
    
    foreach ($def in $ScriptDefinitions) {
        $tileColor = if ($def.Color) { [Color]::FromName($def.Color) } else { [Color]::LightSlateGray }
        
        $btn = [Button]@{
            Text      = $def.Name
            Width     = 180
            Height    = 100
            BackColor = $tileColor
            ForeColor = [Color]::White
            Font      = [Font]::new("Yu Gothic UI", 12, [FontStyle]::Bold)
            Cursor    = [Cursors]::Hand
            Margin    = [Padding]::new(5)
            FlatStyle = "Flat"
        }
        $btn.FlatAppearance.BorderSize = 0
        
        # クリックイベント：詳細画面へ遷移
        $btn.Add_Click({
            Show-Detail $def
        })
        
        $menuPanel.Controls.Add($btn)
    }
}

# --- 関数: パラメータ画面表示 ---
function Show-Detail($def) {
    $script:currentDef = $def
    $script:currentInputControls.Clear()
    
    # ヘッダー情報更新
    $detailHeader.Text = $def.Name
    $detailHeader.ForeColor = if ($def.Color) { [Color]::FromName($def.Color) } else { [Color]::Black }
    $detailDesc.Text = $def.Description
    
    # 入力フォーム生成
    $detailInputs.Controls.Clear()
    
    if ($def.Params) {
        foreach ($p in $def.Params) {
            $pName = $p.Name
            $pLabel = if ($p.Label) { $p.Label } else { $p.Name }
            $pType = $p.Type
            $pDefault = if ($p.Default) { $p.Default } else { "" }

            # ラベル
            $l = [Label]@{ Text = $pLabel; AutoSize = $true; Margin = [Padding]::new(0, 5, 0, 0) }
            $detailInputs.Controls.Add($l)

            # 入力エリアコンテナ
            $inputContainer = [FlowLayoutPanel]@{
                Width = 540; Height = 35; Margin = [Padding]::new(0, 0, 0, 10)
                FlowDirection = "LeftToRight"; WrapContents = $false
            }

            $txtBox = [TextBox]@{ Width = 400; Text = $pDefault; Font = [Font]::new("Consolas", 10) }
            $currentInputControls[$pName] = $txtBox

            if ($pType -eq "File") {
                $inputContainer.Controls.Add($txtBox)
                $btnBrowse = [Button]@{ Text = "..."; Width = 40; Height = 25 }
                $btnBrowse.Add_Click({
                    $dlg = [OpenFileDialog]@{ Filter = if ($p.Filter) { $p.Filter } else { "All Files|*.*" } }
                    if ($dlg.ShowDialog() -eq "OK") {
                        $txtBox.Text = $dlg.FileName
                    }
                })
                $inputContainer.Controls.Add($btnBrowse)
            }
            else {
                $txtBox.Width = 500
                $inputContainer.Controls.Add($txtBox)
            }
            $detailInputs.Controls.Add($inputContainer)
        }
    } else {
        $lblNone = [Label]@{ Text = "パラメータはありません。このまま実行できます。"; AutoSize = $true; ForeColor = [Color]::Gray }
        $detailInputs.Controls.Add($lblNone)
    }

    # 画面切り替え
    $menuPanel.Visible = $false
    $detailPanel.Visible = $true
}

# --- イベント: 戻るボタン ---
$btnBack.Add_Click({
    $detailPanel.Visible = $false
    $menuPanel.Visible = $true
})

# --- イベント: 実行ボタン ---
$btnRun.Add_Click({
    $def = $script:currentDef
    if (-not $def) { return }

    # パス解決
    $scriptFullPath = Join-Path $PSScriptRoot $def.ScriptPath
    
    if (-not (Test-Path $scriptFullPath)) {
        [MessageBox]::Show("スクリプトファイルが見つかりません。`n$scriptFullPath", "エラー", "OK", "Error")
        return
    }

    # 引数構築
    $argsList = @()
    foreach ($key in $currentInputControls.Keys) {
        $val = $currentInputControls[$key].Text
        $typeInfo = $def.Params | Where-Object { $_.Name -eq $key } 
        $type = $typeInfo.Type
        
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            $argsList += "-$key"
            if ($type -eq "String" -or $type -eq "File") {
                $argsList += "`"$val`""
            } else {
                $argsList += $val
            }
        }
    }
    
    $argString = $argsList -join " "
    
    # 実行
    $processInfo = [System.Diagnostics.ProcessStartInfo]@{
        FileName = "pwsh"
        Arguments = "-NoExit -Command & '$scriptFullPath' $argString"
        UseShellExecute = $true
    }
    
    try {
        [System.Diagnostics.Process]::Start($processInfo)
    }
    catch {
        [MessageBox]::Show("実行失敗: $($_.Exception.Message)", "エラー", "OK", "Error")
    }
})

# --- 初期化・起動 ---
Build-Menu
$form.ShowDialog() | Out-Null
$form.Dispose()
