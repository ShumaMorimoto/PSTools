function Update-GPXAddressMetadata {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputPath,
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $OutputPath = [System.IO.Path]::ChangeExtension($InputPath, ".enriched.gpx")
    }

    $gpx = [GPXService]::new()
    try {
        $gpx.Load($InputPath)
    } catch {
        Write-Error "ファイルの読み込み失敗: $_"
        return
    }

    $pts = $gpx.GetTrkpts()
    $total = $pts.Count
    Write-Host "処理開始: $total 件のポイントを解析中..." -ForegroundColor Cyan

    for ($i = 0; $i -lt $total; $i++) {
        $pt = $pts[$i]
        
        # 1. 位置情報から住所情報を解決 (GSI API + Local JSON Cache)
        # 戻り値には extensions に prefecture, municipality, block 等が含まれる
        $enriched = [GeoService]::ResolveAddress($pt)

        $ext = $enriched['extensions']
        $pref = $ext['prefecture']
        $muni = $ext['municipality']
        $town = $ext['block'] # 町字（lv01Nm）

        # 2. name の更新（なければ町字を入れる）
        if ([string]::IsNullOrWhiteSpace($enriched['name'])) {
            $enriched['name'] = $town
        }

        # 3. desc の設定（都道府県＋市区町村＋町字）
        $enriched['desc'] = "{0}{1}{2}" -f $pref, $muni, $town

        # 4. extensions への keyword 設定（なければ町字を入れる）
        if (-not $ext.ContainsKey('keyword') -or [string]::IsNullOrWhiteSpace($ext['keyword'])) {
            $ext['keyword'] = $town
        }

        # 更新したハッシュテーブルを配列に戻す
        $pts[$i] = $enriched

        # 進捗表示
        if ($i % 10 -eq 0) {
            $percent = [math]::Round(($i / $total) * 100)
            Write-Progress -Activity "住所補完中" -Status "$i / $total" -PercentComplete $percent
        }
    }

    # 5. モデルの更新と保存
    $gpx.SetTrkpts($pts)
    $gpx.Save($OutputPath)

    Write-Host "完了しました！" -ForegroundColor Green
    Write-Host "保存先: $OutputPath"
}