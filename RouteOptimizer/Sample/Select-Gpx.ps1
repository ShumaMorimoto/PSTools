using module RouteOptimizer
Add-Type -AssemblyName PresentationFramework

function Select-PlacesWpf {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputGpxPath,

        [Parameter()]
        [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.selected.gpx')"
    )

    try {
        $gpxDoc = [GPXDocument]::Load($InputGpxPath)
        $trkpts = $gpxDoc.GetTrkPts()

        $window = New-Object Windows.Window
        $window.Title = "拠点選択ツール (WPF)"
        $window.Width = 650
        $window.Height = 800

        $grid = New-Object Windows.Controls.Grid
        $window.Content = $grid

        $datagrid = New-Object Windows.Controls.DataGrid
        $datagrid.SelectionMode = "Extended"
        $datagrid.AutoGenerateColumns = $false
        $datagrid.Margin = "10"
		$datagrid.FontSize = 14

        # 列定義
        $datagrid.Columns.Add((New-Object Windows.Controls.DataGridTextColumn -Property @{Header="インデックス"; Binding=[Windows.Data.Binding]::new("Index")}))
        $datagrid.Columns.Add((New-Object Windows.Controls.DataGridTextColumn -Property @{Header="拠点名"; Binding=[Windows.Data.Binding]::new("Name")}))
        $datagrid.Columns.Add((New-Object Windows.Controls.DataGridTextColumn -Property @{Header="緯度"; Binding=[Windows.Data.Binding]::new("Lat")}))
        $datagrid.Columns.Add((New-Object Windows.Controls.DataGridTextColumn -Property @{Header="経度"; Binding=[Windows.Data.Binding]::new("Lon")}))
        $datagrid.Columns.Add((New-Object Windows.Controls.DataGridTextColumn -Property @{Header="次の拠点までの距離(km)"; Binding=[Windows.Data.Binding]::new("Distance")}))

        # データ投入
        $results = @()
        for ($i=0; $i -lt $trkpts.Count; $i++) {
            $pt = $trkpts[$i]
            $dist = ""
            if ($i -lt $trkpts.Count-1) {
                $next = $trkpts[$i+1]
                $dist = 0
            }
            $results += [PSCustomObject]@{
                Index    = $i
                Name     = $pt.name
                Lat      = $pt.lat
                Lon      = $pt.lon
                Distance = $dist
                _trkpt   = $pt
            }
        }
        $datagrid.ItemsSource = $results
        [void]$grid.Children.Add($datagrid)

        $btnOk = New-Object Windows.Controls.Button
        $btnOk.Content = "選択完了"
        $btnOk.Margin = "10"
        $btnOk.HorizontalAlignment = "Right"
        $btnOk.VerticalAlignment = "Bottom"
        $btnOk.Add_Click({
            $selected = $datagrid.SelectedItems | ForEach-Object { $_._trkpt }
            if ($selected.Count -gt 0) {
                $gpxDoc.SetTrkPts($selected)
                $gpxDoc.Save($OutputGpxPath)
                [System.Windows.MessageBox]::Show("✅ 選択した拠点を保存しました: $OutputGpxPath","完了")
            }
            else {
                [System.Windows.MessageBox]::Show("拠点が選択されていません","注意")
            }
            $window.Close()
        })
        [void]$grid.Children.Add($btnOk)

        $window.ShowDialog() | Out-Null
    }
    catch {
        Write-Error "❌ GPXファイル処理に失敗: $($_.Exception.Message)"
    }
}

Select-PlacesWpf