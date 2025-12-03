Add-Type -AssemblyName PresentationFramework

# === Compare-PsObject（簡易版） ===
function Compare-PsObject {
    param($a, $b)
    (ConvertTo-Json $a -Compress) -eq (ConvertTo-Json $b -Compress)
}

# === Grid生成関数 ===
function New-ResultGrid {
    param([string]$Name)

    $grid = New-Object Windows.Controls.DataGrid
    $grid.Margin = "10"
    $grid.Height = 300
    $grid.FontSize = 16
    $grid.AutoGenerateColumns = $true
    $grid.IsReadOnly = $true                # 編集禁止
    $grid.SelectionMode = "Single"          # 単一選択
    $grid.SelectionUnit = "FullRow"         # 行単位選択

    # 固定参照を閉じ込める
    $gridref = $grid

    # "_" 始まりの列はキャンセル
    $grid.Add_AutoGeneratingColumn({
        param($sender, $e)
        if ($e.PropertyName -match '^_') {
            $e.Cancel = $true
        }
    })

    # Tagにデフォルト設定とUpdateGrid関数をまとめる
    $grid.Tag = @{
        Name           = $Name
        HighlightBrush = [Windows.Media.Brushes]::LightYellow
        SelectionBrush = [Windows.Media.Brushes]::LightGreen

        UpdateGrid     = {
            param($results, $history, $comparer)

            foreach ($r in $results) {
                $isMatch = $false
                foreach ($h in $history) {
                    if (& $comparer $r $h) { $isMatch = $true; break }
                }
                # 内部フラグは "_" 始まり
                $r | Add-Member -NotePropertyName _IsHistoryMatch -NotePropertyValue $isMatch -Force
            }

            $sorted = $results | Sort-Object { -not $_._IsHistoryMatch }
            $gridref.ItemsSource = @($sorted)
        }.GetNewClosure()
    }

    # 行生成時に色付け
    $grid.Add_LoadingRow({
        param($sender, $e)
        $item = $e.Row.Item
        if ($item._IsHistoryMatch) {
            $e.Row.Background = $sender.Tag.HighlightBrush
        }
    })

    # 選択イベント（選択行を緑色に）
    $grid.Add_SelectionChanged({
        $selected = $grid.SelectedItem
        if ($selected) {
            $row = $grid.ItemContainerGenerator.ContainerFromItem($selected)
            if ($row -is [Windows.Controls.DataGridRow]) {
                $row.Background = $grid.Tag.SelectionBrush
            }
            Write-Host "選択された: $($selected.拠点名) → $($selected.緯度),$($selected.経度)"
        }
    })

    return $grid
}

# === ダミーデータ ===
$results = @(
    [pscustomobject]@{ 拠点名="函館駅"; 緯度=41.773; 経度=140.726 },
    [pscustomobject]@{ 拠点名="札幌駅"; 緯度=43.068; 経度=141.350 },
    [pscustomobject]@{ 拠点名="東京駅"; 緯度=35.681; 経度=139.767 }
)

$history = @(
    @{ lat = 41.773; lon = 140.726 }   # 函館駅を履歴に持っている
)

# 比較関数
$compareFn = {
    param($result, $historyItem)
    Compare-PsObject $historyItem @{ lat = $result.緯度; lon = $result.経度 }
}

# === Grid生成と更新 ===
$datagrid = New-ResultGrid -Name "TestGrid"
$datagrid.Tag.UpdateGrid.Invoke($results, $history, $compareFn)

# === ウィンドウ表示 ===
$window = New-Object Windows.Window
$window.Title = "UpdateGrid テスト"
$window.Width = 500
$window.Height = 400
$window.Content = $datagrid
$window.ShowDialog() | Out-Null