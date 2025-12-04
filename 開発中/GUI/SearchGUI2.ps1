using module RouteOptimizer

# 必要アセンブリをロード
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

# === ここまでに EntryBase/Entry, Load/Save/Refresh/Add/Get, New-SearchCombo, New-ResultGrid を定義済み前提 ===
class EntryBase {
    EntryBase() { }
    [bool] Equals([object] $other) { throw "Equals must be implemented in derived class" }
    [string] ToString() { throw "ToString must be implemented in derived class" }
    [string] ToJson() { return ($this | ConvertTo-Json -Compress) }
    static [EntryBase] FromJson([object]$obj) { throw "FromJson must be implemented in derived class" }
}

class PlaceEntry : EntryBase {
    [System.Xml.XmlElement] $_trkpt   # 元のXMLノードを保持
    [string] $拠点名   
    [string] $住所   
    [double] $緯度  
    [double] $経度
    
    PlaceEntry() { }

    PlaceEntry([System.Xml.XmlElement]$trkpt) {
        $this._trkpt  = $trkpt
        $this.拠点名  = $trkpt.name
        $this.住所    = [GPXDocument]::GetTownName($trkpt, 3)
        $this.緯度    = [double]$trkpt.GetAttribute("lat")
        $this.経度    = [double]$trkpt.GetAttribute("lon")
    }

    PlaceEntry([string] $name,
               [string] $address,   
               [double] $lat, 
               [double] $lon ) {
        $this._trkpt  = $null   # XMLから生成していない場合は null
        $this.拠点名  = $name
        $this.住所    = $address
        $this.緯度    = $lat
        $this.経度    = $lon
    }

    [bool] Equals([object] $other) {
        if ($null -eq $other) { return $false }
        if ($other -is [PlaceEntry]) {
            return ($this.経度 -eq $other.経度 -and $this.緯度 -eq $other.緯度)
        }
        return $false
    }

    static [PlaceEntry] FromJson([object]$obj) {
        return [PlaceEntry]::new($obj.拠点名, $obj.住所, [double]$obj.緯度, [double]$obj.経度)
    }
    [string] ToString() { return "hoge" }

}


# メインWindow
$window = New-Object System.Windows.Window
$window.Title = "検索GUI"
$window.Width = 600
$window.Height = 420

# Gridレイアウト（2行: 上=メイン, 下=ステータス表示）
$grid = New-Object System.Windows.Controls.Grid
$rowMain = New-Object System.Windows.Controls.RowDefinition
$rowStatus = New-Object System.Windows.Controls.RowDefinition
$rowStatus.Height = "30"
$grid.RowDefinitions.Add($rowMain)
$grid.RowDefinitions.Add($rowStatus)
$window.Content = $grid

# 上段のレイアウト（StackPanel）
$topPanel = New-Object System.Windows.Controls.StackPanel
$topPanel.Margin = "10"
[System.Windows.Controls.Grid]::SetRow($topPanel, 0)
$grid.Children.Add($topPanel)

# --- (1) 検索コンボ部品（履歴管理付き） ---
$combo = New-SearchCombo -Name "testplaces"
$combo.Width = 240
$combo.Tag.EntryClass = [PlaceEntry]
$topPanel.Children.Add($combo)

# --- (2) 結果グリッド部品（汎用部品に置き換え） ---
$dataGrid = New-ResultGrid -Name "ResultGrid"
$dataGrid.Margin = "0,10,0,0"
$dataGrid.Height = 300
$topPanel.Children.Add($dataGrid)

# --- ステータスバー ---
$statusPanel = New-Object System.Windows.Controls.DockPanel
$statusPanel.LastChildFill = $true
$statusPanel.Margin = "2,0,2,2"
[System.Windows.Controls.Grid]::SetRow($statusPanel, 1)
$grid.Children.Add($statusPanel)

$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Text = "準備完了"
$statusText.VerticalAlignment = "Center"
$statusText.FontSize = 12
$statusText.Padding = "2,2"
$statusPanel.Children.Add($statusText)

function Set-Status([string]$msg) { $statusText.Text = $msg }

# ダミー検索関数（差し替え可能）
function Invoke-Search([string]$keyword) {
    $towns = ([GPXDocumentFactory]::Search($keyword)).GetTrkPts()
    $results = @()
    foreach($town in $towns){
        $pt = [PlaceEntry]::new($town)
        $results += $pt        
    }
    return $results
}

# --- コンボのイベント連動 ---
# Enterキーで検索実行
$combo.Tag.Entered = [Action[string]] {
    param($kw)
    if ([string]::IsNullOrWhiteSpace($kw)) {
        Set-Status "キーワードが空です"
        return
    }
    Set-Status "検索中…"

    $results = Invoke-Search $kw
    # Grid部品のUpdateGridを利用
    $dataGrid.Tag.UpdateGrid.Invoke($results, @())

    # 履歴に拠点オブジェクトを追加（ダミー）
#    $cls = $combo.Tag.EntryClass
#    $combo.Tag.AddHistory.Invoke($kw, $cls::new("X", "拠点X"))

    Set-Status "検索完了（件数: $($results.Count)）"
}

# --- Grid部品のSelectedイベントを差し替え ---
$dataGrid.Tag.Selected = {
    param($entry)
    # 詳細ウィンドウを開く処理
    $detailWin = New-Object System.Windows.Window
    $detailWin.Title = "詳細情報: $($entry.Name)"
    $detailWin.Width = 360
    $detailWin.Height = 300
    $detailWin.Owner = $window
    $detailWin.WindowStartupLocation = "CenterOwner"

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = "10"
    $detailWin.Content = $panel

    $detailGrid = New-Object System.Windows.Controls.DataGrid
    $detailGrid.AutoGenerateColumns = $true
    $detailGrid.SelectionMode = "Extended"
    $detailGrid.SelectionUnit = "FullRow"
    $detailGrid.Height = 200
    $detailGrid.ItemsSource = @(
        @{Detail = "詳細1_$($entry.Name)" }
        @{Detail = "詳細2_$($entry.Name)" }
        @{Detail = "詳細3_$($entry.Name)" }
    )
    $panel.Children.Add($detailGrid)

    $copyButton = New-Object System.Windows.Controls.Button
    $copyButton.Content = "選択をまとめてコピー"
    $copyButton.Margin = "0,8,0,0"
    $copyButton.Add_Click({
            param($s, $args)
            if ($detailGrid.SelectedItems.Count -le 0) {
                [System.Windows.MessageBox]::Show("選択がありません")
                return
            }
            $clipText = ($detailGrid.SelectedItems | ForEach-Object { $_.Detail }) -join "`r`n"
            [System.Windows.Clipboard]::SetText($clipText)
            Set-Status "コピーしました（$($detailGrid.SelectedItems.Count) 件）"
            [System.Windows.MessageBox]::Show("コピーしました:`n$clipText")
        })
    $panel.Children.Add($copyButton)

    $detailWin.ShowDialog() | Out-Null
}

# 表示
$window.ShowDialog() | Out-Null