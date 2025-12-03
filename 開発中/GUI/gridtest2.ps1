Add-Type -AssemblyName PresentationFramework

# STAチェック（PowerShell 7系では必要）
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    powershell.exe -sta -NoProfile -Command $PSCommandPath
    return
}

# === Grid生成関数 ===
function New-ResultGrid {
    $grid = New-Object Windows.Controls.DataGrid
    $grid.Margin = "10"
    $grid.Height = 300
    $grid.FontSize = 16
    $grid.AutoGenerateColumns = $true

    # TagにUpdateGrid関数を保持
    $gridref = $grid
    $grid.Tag = @{
        UpdateGrid = {
            param($results)

            # 必ず配列化して ItemsSource に設定
            $gridref.ItemsSource = @($results)
        }.GetNewClosure()
    }

    return $grid
}

# === ダミーデータ（必ず配列） ===
$results = @(
    [pscustomobject]@{ 拠点名="函館駅"; 緯度=41.773; 経度=140.726 },
    [pscustomobject]@{ 拠点名="札幌駅"; 緯度=43.068; 経度=141.350 },
    [pscustomobject]@{ 拠点名="東京駅"; 緯度=35.681; 経度=139.767 }
)

# === Grid生成とTAG呼び出し ===
$datagrid = New-ResultGrid
$datagrid.Tag.UpdateGrid.Invoke($results)

# === ウィンドウ表示 ===
$window = New-Object Windows.Window
$window.Title = "TAG呼び出しテスト"
$window.Width = 500
$window.Height = 400
$window.Content = $datagrid
$window.ShowDialog() | Out-Null