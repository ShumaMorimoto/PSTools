function Select-Places {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Places
    )

    $form = New-Object Windows.Forms.Form
    $form.Text = "拠点選択ツール"
    $form.Size = New-Object Drawing.Size(900,500)

    $grid = New-Object Windows.Forms.DataGridView
    $grid.Dock = "Fill"
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $true
    $grid.AutoSizeColumnsMode = "Fill"

    # 列定義
    $colSel = New-Object Windows.Forms.DataGridViewCheckBoxColumn
    $colSel.Name = "Selected"
    $colSel.HeaderText = "選択"
    $grid.Columns.Add($colSel) | Out-Null
    $grid.Columns.Add("Order","順番") | Out-Null
    $grid.Columns.Add("Name","拠点名") | Out-Null
    $grid.Columns.Add("Lat","緯度") | Out-Null
    $grid.Columns.Add("Lon","経度") | Out-Null
    $grid.Columns.Add("Distance","次の拠点までの距離(km)") | Out-Null

    # データ投入
    $index = 1
    for ($i=0; $i -lt $Places.Count; $i++) {
        $pt = $Places[$i]
        $lat = [double]$pt.Lat
        $lon = [double]$pt.Lon

        $dist = ""
        if ($i -lt $Places.Count-1) {
            $next = $Places[$i+1]
            $dist = "{0:N2}" -f (Get-Distance $pt $next)
        }

        $grid.Rows.Add($false, $index, $pt.Name, $lat, $lon, $dist) | Out-Null
        $index++
    }

    # 選択変更イベント
    $grid.Add_SelectionChanged({
        foreach ($row in $grid.SelectedRows) {
            $row.Cells["Selected"].Value = $true
        }
    })

    $form.Controls.Add($grid)

    # OKボタン
    $btnOk = New-Object Windows.Forms.Button
    $btnOk.Text = "選択完了"
    $btnOk.Dock = "Bottom"
    $btnOk.Add_Click({
        $form.Tag = foreach ($row in $grid.Rows) {
            if ($row.Cells["Selected"].Value -eq $true) {
                $Places | Where-Object { $_.Name -eq $row.Cells["Name"].Value }
            }
        }
        $form.Close()
    })
    $form.Controls.Add($btnOk)

    $form.ShowDialog() | Out-Null

    return $form.Tag
}


param (
    [Parameter(Mandatory = $true)]
    [string]$InputGpxPath,

    [Parameter()]
    [string]$OutputGpxPath = "$($InputGpxPath -replace '\.gpx$', '.selected.gpx')"
)

# ① GPX読み込み
[xml] $gpx = Get-Content $InputGpxPath

# ② 拠点取得
$trkpts = $gpx.gpx.trk.trkseg.trkpt

# 選択
$selected = Select-Places -Places $trkpts

# 再構築
$trkseg = $gpx.gpx.trk.trkseg
$trkseg.RemoveAll()
foreach ($pt in $selected) {
    $trkseg.AppendChild($gpx.ImportNode($pt, $true)) | Out-Null
}

# 統計情報追加
$gpx = Add-GpxStats -GpxXml $gpx

# 保存
try {
    $gpx.Save($OutputGpxPath)
    Write-Host "✅ 選択GPXファイルを保存しました: $OutputGpxPath" -ForegroundColor Green
}
catch {
    Write-Error "❌ GPXファイル保存に失敗: $($_.Exception.Message)"
}