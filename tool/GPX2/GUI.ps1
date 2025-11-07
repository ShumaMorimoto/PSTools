#Requires -Version 5.1
<#
.SYNOPSIS
    地名キーワードから緯度経度を検索し、クリップボードにコピーするGUIツール。
.DESCRIPTION
    地名を入力し、検索ボタンを押すと候補がリスト表示されます。
    リストから項目を選択（またはダブルクリック）すると、その場所の緯度経度を
    「緯度,経度」の形式でクリップボードにコピーします。
    国土地理院(GSI)とOpenStreetMap(OSM)の2つの検索ソースを切り替え可能です。
#>

# =============================================================================
#  1. バックエンド関数 (前回作成したデータ取得ロジック)
# =============================================================================
function Get-GeoLocation {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Keyword,

        [Parameter()]
        [ValidateSet("GSI", "OSM")]
        [string]$Source = "GSI"
    )

    try {
        Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
        $encodedKeyword = [System.Web.HttpUtility]::UrlEncode($Keyword)
        $results = @()
        
        switch ($Source) {
            "GSI" {
                $uri = "https://msearch.gsi.go.jp/address-search/AddressSearch?q=$encodedKeyword"
                $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop -TimeoutSec 10
                if ($null -ne $response) {
                    $responseArray = if ($response -is [array]) { $response } else { @($response) }
                    foreach ($item in $responseArray) {
                        $results += [PSCustomObject]@{
                            DisplayName = $item.properties.title
                            Latitude    = $item.geometry.coordinates[1]
                            Longitude   = $item.geometry.coordinates[0]
                            SourceAPI   = "GSI"
                        }
                    }
                }
            }
            "OSM" {
                $uri = "https://nominatim.openstreetmap.org/search?q=$encodedKeyword&format=json&limit=20"
                $headers = @{ "User-Agent" = "PowerShell-Geocoding-GUI/1.0" }
                $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop -TimeoutSec 10
                if ($null -ne $response) {
                    $responseArray = if ($response -is [array]) { $response } else { @($response) }
                    foreach ($item in $responseArray) {
                        $results += [PSCustomObject]@{
                            DisplayName = $item.display_name
                            Latitude    = [double]$item.lat
                            Longitude   = [double]$item.lon
                            SourceAPI   = "OSM"
                        }
                    }
                }
            }
        }
        return $results
    } catch {
        # GUIなのでエラーはダイアログで表示する
        [System.Windows.Forms.MessageBox]::Show("検索中にエラーが発生しました。`n`n$($_.Exception.Message)", "検索エラー", "OK", "Error")
        return $null
    }
}


# =============================================================================
#  2. GUIの構築とイベントハンドリング
# =============================================================================
try {
    # 必要なアセンブリを読み込む
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # -------------------------------------------------
    # フォーム（ウィンドウ）の作成
    # -------------------------------------------------
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "緯度経度 検索ツール"
    $form.Size = New-Object System.Drawing.Size(600, 450)
    $form.MinimumSize = $form.Size
    $form.StartPosition = "CenterScreen"
    $form.KeyPreview = $true # Enterキーでの検索を有効にするため

    # -------------------------------------------------
    # GUIコントロール（部品）の作成
    # -------------------------------------------------
    $labelKeyword = New-Object System.Windows.Forms.Label
    $labelKeyword.Location = New-Object System.Drawing.Point(10, 15)
    $labelKeyword.Size = New-Object System.Drawing.Size(80, 20)
    $labelKeyword.Text = "キーワード:"
    $form.Controls.Add($labelKeyword)

    $textBoxKeyword = New-Object System.Windows.Forms.TextBox
    $textBoxKeyword.Location = New-Object System.Drawing.Point(90, 12)
    $textBoxKeyword.Size = New-Object System.Drawing.Size(300, 20)
    $form.Controls.Add($textBoxKeyword)

    $groupBoxSource = New-Object System.Windows.Forms.GroupBox
    $groupBoxSource.Location = New-Object System.Drawing.Point(400, 5)
    $groupBoxSource.Size = New-Object System.Drawing.Size(80, 70)
    $groupBoxSource.Text = "ソース"
    $form.Controls.Add($groupBoxSource)

    $radioGSI = New-Object System.Windows.Forms.RadioButton
    $radioGSI.Location = New-Object System.Drawing.Point(10, 20)
    $radioGSI.Text = "GSI"
    $radioGSI.Checked = $true # デフォルトで選択
    $groupBoxSource.Controls.Add($radioGSI)
    
    $radioOSM = New-Object System.Windows.Forms.RadioButton
    $radioOSM.Location = New-Object System.Drawing.Point(10, 40)
    $radioOSM.Text = "OSM"
    $groupBoxSource.Controls.Add($radioOSM)

    $buttonSearch = New-Object System.Windows.Forms.Button
    $buttonSearch.Location = New-Object System.Drawing.Point(490, 30)
    $buttonSearch.Size = New-Object System.Drawing.Size(90, 30)
    $buttonSearch.Text = "検索"
    $form.Controls.Add($buttonSearch)

    $listBoxResults = New-Object System.Windows.Forms.ListBox
    $listBoxResults.Location = New-Object System.Drawing.Point(10, 85)
    $listBoxResults.Size = New-Object System.Drawing.Size(570, 300)
    $listBoxResults.Anchor = 'Top, Bottom, Left, Right' # ウィンドウサイズ変更に追従
    $form.Controls.Add($listBoxResults)

    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Text = "検索キーワードを入力してください。"
    $form.Controls.Add($statusBar)

    # -------------------------------------------------
    # イベントハンドラの定義
    # -------------------------------------------------

    # 検索ボタンのクリック処理
    $SearchAction = {
        if ([string]::IsNullOrWhiteSpace($textBoxKeyword.Text)) {
            $statusBar.Text = "キーワードが入力されていません。"
            return
        }

        # 検索中の表示
        $statusBar.Text = "検索中..."
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $buttonSearch.Enabled = $false
        $form.Update() # 表示を強制更新

        $source = if ($radioGSI.Checked) { "GSI" } else { "OSM" }
        $results = Get-GeoLocation -Keyword $textBoxKeyword.Text -Source $source
        
        # 検索結果をリストボックスに設定
        $listBoxResults.DataSource = $null # 一度クリア
        if ($results) {
            $listBoxResults.DataSource = $results
            $listBoxResults.DisplayMember = "DisplayName"
            $statusBar.Text = "$($results.Count) 件の候補が見つかりました。リストをダブルクリックするか、選択してEnterキーでコピーします。"
        } else {
            $statusBar.Text = "候補が見つかりませんでした。"
        }

        # 検索完了後の表示
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $buttonSearch.Enabled = $true
    }

    # クリップボードへのコピー処理
    $CopyToClipboardAction = {
        if ($listBoxResults.SelectedItem) {
            $selected = $listBoxResults.SelectedItem
            $clipboardText = "$($selected.Latitude),$($selected.Longitude)"
            Set-Clipboard -Value $clipboardText
            $statusBar.Text = "コピーしました: $clipboardText"
        }
    }

    # イベントハンドラをコントロールに登録
    $buttonSearch.Add_Click($SearchAction)
    
    # テキストボックスでEnterキーを押したら検索
    $form.Add_KeyDown({
        if ($_.KeyCode -eq "Enter") {
            # アクティブなコントロールがテキストボックスの場合のみ検索を実行
            if ($form.ActiveControl -eq $textBoxKeyword) {
                $SearchAction.Invoke()
                # Enterキーのビープ音を抑制
                $_.SuppressKeyPress = $true
            }
        }
    })

    # リストボックスでEnterキーを押したらコピー
    $listBoxResults.Add_KeyDown({
        if ($_.KeyCode -eq "Enter") {
            $CopyToClipboardAction.Invoke()
            # Enterキーのビープ音を抑制
            $_.SuppressKeyPress = $true
        }
    })

    # リストボックスの項目をダブルクリックしたらコピー
    $listBoxResults.Add_DoubleClick($CopyToClipboardAction)
    
    # 選択項目が変わったらステータスバーに緯度経度を表示
    $listBoxResults.Add_SelectedIndexChanged({
        if ($listBoxResults.SelectedItem) {
            $selected = $listBoxResults.SelectedItem
            $statusBar.Text = "選択中: $($selected.Latitude), $($selected.Longitude)"
        }
    })

    # -------------------------------------------------
    # フォームの表示
    # -------------------------------------------------
    $form.Add_Shown({$textBoxKeyword.Focus()}) # 起動時にテキストボックスにフォーカス
    [void]$form.ShowDialog()

    # -------------------------------------------------
    # リソースの解放
    # -------------------------------------------------
    $form.Dispose()

} catch {
    [System.Windows.Forms.MessageBox]::Show("GUIの初期化中に致命的なエラーが発生しました。`n`n$($_.Exception.Message)", "起動エラー", "OK", "Error")
}
