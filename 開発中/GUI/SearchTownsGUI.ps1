using module RouteOptimizer
using module GUITools

# ================================
# PlaceEntry クラス定義
# ================================
class PlaceEntry : EntryBase {
    [System.Xml.XmlElement] $_trkpt   # 元のXMLノードを保持
    [string] $拠点名   
    [string] $住所   
    [double] $緯度  
    [double] $経度
    
    PlaceEntry() { }

    PlaceEntry([System.Xml.XmlElement]$trkpt) {
        $this._trkpt = $trkpt
        $this.拠点名 = $trkpt.name
        $this.住所   = [GPXDocument]::GetTownName($trkpt, 3)
        $this.緯度   = [double]$trkpt.GetAttribute("lat")
        $this.経度   = [double]$trkpt.GetAttribute("lon")
    }

    PlaceEntry([string] $name,
               [string] $address,   
               [double] $lat, 
               [double] $lon ) {
        $this._trkpt = $null   # XMLから生成していない場合は null
        $this.拠点名 = $name
        $this.住所   = $address
        $this.緯度   = $lat
        $this.経度   = $lon
    }

    [bool] Equals([object] $other) {
        if ($null -eq $other) { return $false }
        if ($other -is [PlaceEntry]) {
            return ($this.経度 -eq $other.経度 -and $this.緯度 -eq $other.緯度)
        }
        return $false
    }

    static [PlaceEntry] FromJson([object]$obj) {
        return [PlaceEntry]::new($obj.拠点名, $obj.住所,
                                 [double]$obj.緯度, [double]$obj.経度)
    }

    [string] ToString() { return "hoge" }
}

# ================================
# メイン Window 構築
# ================================
$window = New-Object System.Windows.Window
$window.Title  = "検索GUI"
$window.Width  = 600
$window.Height = 420

# Gridレイアウト（2行: 上=メイン, 下=ステータス表示）
$grid       = New-Object System.Windows.Controls.Grid
$rowMain    = New-Object System.Windows.Controls.RowDefinition
$rowMain.Height = "*"   # 上段は残り全部を使う
$rowStatus  = New-Object System.Windows.Controls.RowDefinition
$rowStatus.Height = "30"
$grid.RowDefinitions.Add($rowMain)
$grid.RowDefinitions.Add($rowStatus)
$window.Content = $grid

# 上段 Grid（ComboBox と DataGrid を分割配置）
$topGrid = New-Object System.Windows.Controls.Grid
$topGrid.Margin = "10"
$topGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # ComboBox行
$topGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # DataGrid行
[System.Windows.Controls.Grid]::SetRow($topGrid, 0)
[void]$grid.Children.Add($topGrid)

# ================================
# (1) 検索コンボ部品
# ================================
$combo = New-UIElement -ElementKey "SearchCombo"
Init-SearchComboLogic -comboBox $combo -Name "testplaces" -EntryClass ([PlaceEntry])
[System.Windows.Controls.Grid]::SetRow($combo, 0)
[void]$topGrid.Children.Add($combo)

# ================================
# (2) 結果グリッド部品
# ================================
$dataGrid = New-UIElement -ElementKey "ResultGrid"
Init-ResultGridLogic -grid $dataGrid -Name "ResultGrid"
$dataGrid.Height = [double]::NaN   # 自動伸縮
[System.Windows.Controls.Grid]::SetRow($dataGrid, 1)
[void]$topGrid.Children.Add($dataGrid)

# ================================
# ステータスバー
# ================================
$statusPanel = New-Object System.Windows.Controls.DockPanel
$statusPanel.LastChildFill = $true
$statusPanel.Margin        = "2,0,2,2"
[System.Windows.Controls.Grid]::SetRow($statusPanel, 1)
[void]$grid.Children.Add($statusPanel)

$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Text               = "準備完了"
$statusText.VerticalAlignment  = "Center"
$statusText.FontSize           = 12
$statusText.Padding            = "2,2"
[void]$statusPanel.Children.Add($statusText)

function Set-Status([string]$msg) { $statusText.Text = $msg }

# ================================
# 検索関数（RouteOptimizer）
# ================================
function Invoke-Search([string]$keyword) {
    $towns   = ([GPXDocumentFactory]::Search($keyword)).GetTrkPts()
    $results = @()
    foreach ($town in $towns) {
        $results += [PlaceEntry]::new($town)
    }
    return , $results
}

# ================================
# コンボのイベント連動
# ================================
$combo.Tag.Entered = [Action[string]] {
    param($kw)
    if ([string]::IsNullOrWhiteSpace($kw)) {
        Set-Status "キーワードが空です"
        return
    }
    Set-Status "検索中…"

    $results = Invoke-Search $kw
    & $dataGrid.Tag.SetData @($results)
    & $dataGrid.Tag.RefreshView @()

    if ($results.Count -eq 1) {
        $dataGrid.SelectedItem = $results[0]
    }
    else {
        Set-Status "検索完了（件数: $($results.Count)）"
    }
}

# ================================
# Grid部品の Selected イベント差し替え
# ================================
$dataGrid.Tag.Selected = {
    param($entry)
    if ($null -eq $entry) { return }

    $clipText = "{0},{1}" -f $entry.緯度, $entry.経度
    [System.Windows.Clipboard]::SetText($clipText)
    Set-Status "座標をコピーしました: $clipText"

    & $combo.Tag.AddHistory $combo.Text $entry
}

# ================================
# 表示
# ================================
$window.ShowDialog() | Out-Null