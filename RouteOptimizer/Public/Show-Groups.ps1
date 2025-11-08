function Show-Groups {
    param (
        [Parameter(Mandatory)]
        [array]$Clusters  # 各クラスタは @{id=..., lat=..., lon=...} の配列
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    $form = New-Object Windows.Forms.Form
    $form.Text = "クラスタと重心円のプロット"
    $form.Width = 800
    $form.Height = 600

    $chart = New-Object Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = 780
    $chart.Height = 560
    $chart.Left = 10
    $chart.Top = 10

    $chartArea = New-Object Windows.Forms.DataVisualization.Charting.ChartArea
    $chartArea.AxisX.Title = "Longitude"
    $chartArea.AxisY.Title = "Latitude"
    $chartArea.AxisY.IsStartedFromZero = $false
    $chartArea.AxisY.Minimum = [double]::NaN
    $chartArea.AxisY.Maximum = [double]::NaN
    $chartArea.AxisY.IntervalAutoMode = 'VariableCount'
    $chartArea.AxisX.Minimum = [double]::NaN
    $chartArea.AxisX.Maximum = [double]::NaN
    $chartArea.AxisX.IntervalAutoMode = 'VariableCount'
    $chart.ChartAreas.Add($chartArea)

    $colors = @("Red", "Blue", "Green", "Orange", "Purple", "Brown", "Teal", "DarkCyan", "DarkMagenta", "DarkGoldenrod")

    for ($i = 0; $i -lt $Clusters.Count; $i++) {
        $cluster = $Clusters[$i]
        $series = New-Object Windows.Forms.DataVisualization.Charting.Series "Cluster$i"
        $series.ChartType = 'Point'
        $series.Color = $colors[$i % $colors.Count]
        $series.MarkerSize = 8
        $series.IsValueShownAsLabel = $false

        $lats = @()
        $lons = @()

        foreach ($pt in $cluster) {
            $lats += [double]$pt.lat
            $lons += [double]$pt.lon
            $series.Points.AddXY($pt.lon, $pt.lat) | Out-Null
        }

        # 重心計算
        $latAvg = ($lats | Measure-Object -Average).Average
        $lonAvg = ($lons | Measure-Object -Average).Average

        # 最大距離（ユークリッド距離）
        $maxDist = 0.0
        for ($j = 0; $j -lt $lats.Count; $j++) {
            $dx = $lats[$j] - $latAvg
            $dy = $lons[$j] - $lonAvg
            $dist = [math]::Sqrt($dx * $dx + $dy * $dy)
            if ($dist -gt $maxDist) { $maxDist = $dist }
        }

        # 円描画（Seriesで近似）
        $circle = New-Object Windows.Forms.DataVisualization.Charting.Series "Circle$i"
        $circle.ChartType = 'Spline'
        $circle.Color = $colors[$i % $colors.Count]
        $circle.BorderDashStyle = 'Dash'
        $circle.BorderWidth = 1

        for ($theta = 0; $theta -le 360; $theta += 5) {
            $rad = $theta * [math]::PI / 180
            $x = $lonAvg + $maxDist * [math]::Cos($rad)
            $y = $latAvg + $maxDist * [math]::Sin($rad)
            $circle.Points.AddXY($x, $y) | Out-Null
        }

        $chart.Series.Add($series)
        $chart.Series.Add($circle)
    }

    $form.Controls.Add($chart)
    $form.ShowDialog()
}
