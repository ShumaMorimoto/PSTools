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
    $grid.Columns.Add("Order","インデックス") | Out-Null
    $grid.Columns.Add("Name","拠点名") | Out-Null
    $grid.Columns.Add("Lat","緯度") | Out-Null
    $grid.Columns.Add("Lon","経度") | Out-Null
    $grid.Columns.Add("Distance","次の拠点までの距離(km)") | Out-Null

    # データ投入（初期はすべて非選択）
    for ($i=0; $i -lt $Places.Count; $i++) {
        $pt = $Places[$i]
        $lat = [double]$pt.Lat
        $lon = [double]$pt.Lon

        $dist = ""
        if ($i -lt $Places.Count-1) {
            $next = $Places[$i+1]
            $dist = "{0:N2}" -f (Get-Distance $pt $next)
        }

        # 初期値は Selected = $false
        $grid.Rows.Add($false, $i, $pt.Name, $lat, $lon, $dist) | Out-Null
    }

    # 選択変更イベントは削除 → 行選択してもチェックは入らない
    # ユーザーがチェックボックスを直接操作する仕様にする

    $form.Controls.Add($grid)

    # OKボタン
    $btnOk = New-Object Windows.Forms.Button
    $btnOk.Text = "選択完了"
    $btnOk.Dock = "Bottom"
    $btnOk.Add_Click({
        $form.Tag = foreach ($row in $grid.Rows) {
            if ($row.Cells["Selected"].Value -eq $true) {
                $Places[[int]$row.Cells["Order"].Value]
            }
        }
        $form.Close()
    })
    $form.Controls.Add($btnOk)

    $form.ShowDialog() | Out-Null

    return $form.Tag
}