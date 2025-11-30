using module RouteOptimizer
Add-Type -AssemblyName PresentationFramework

function Write-PlaceLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Trkpt
    )

    if (-not (Test-Path $FilePath)) {
        $doc = [GPXDocument]::new("SearchPlaceLog")
        $doc.Save($FilePath)
    }

    $doc = [GPXDocument]::Load($FilePath)
    $doc.AppendTrkPt($Trkpt)
    $doc.Save($FilePath)
}

function Start-KeywordListGui {
    param (
        [string]$FilePath = "D:\tool\log\SearchPlaceLog.gpx"
    )

    $window = New-Object Windows.Window
    $window.Title = "Place Search Tool"
    $window.Width = 600
    $window.Height = 400

    $stack = New-Object Windows.Controls.StackPanel
    $stack.Margin = "10"
    $window.Content = $stack

    # ラベル
    $label = New-Object Windows.Controls.Label
    $label.Content = "キーワードを入力してください:"
    $label.FontSize = 18
    $stack.Children.Add($label)

    # テキストボックス
    $textbox = New-Object Windows.Controls.TextBox
    $textbox.Height = 30
    $textbox.FontSize = 18
    $stack.Children.Add($textbox)

    # 検索ボタン
    $searchBtn = New-Object Windows.Controls.Button
    $searchBtn.Content = "検索"
    $searchBtn.Margin = "0,10,0,0"
    $searchBtn.Height = 35
    $searchBtn.FontSize = 18
    $stack.Children.Add($searchBtn)

    # 一覧表示用 DataGrid
    $datagrid = New-Object Windows.Controls.DataGrid
    $datagrid.Margin = "0,10,0,0"
    $datagrid.Height = 250
    $datagrid.FontSize = 16
    $stack.Children.Add($datagrid)

    # 検索処理
    $searchAction = {
        $keyword = $textbox.Text
        if (-not $keyword -or $keyword.Trim() -eq "") {
            [System.Windows.MessageBox]::Show("キーワードを入力してください","注意")
            return
        }

        try {
            $trkpts = ([GPXDocumentFactory]::Search($keyword)).GetTrkPts()

            if (-not $trkpts -or $trkpts.Count -eq 0) {
                [System.Windows.MessageBox]::Show("検索結果が見つかりませんでした","結果")
                $datagrid.ItemsSource = $null
                return
            }

            # 1件だけなら自動コピー＆ログ保存
            if ($trkpts.Count -eq 1) {
                $trkpt = $trkpts[0]
                $text = "$($trkpt.lat),$($trkpt.lon)"
                Set-Clipboard -Value $text
                Write-PlaceLog -FilePath $FilePath -Trkpt $trkpt
                [System.Windows.MessageBox]::Show("検索結果が1件のため自動コピーしました: $text","結果")
                $datagrid.ItemsSource = $null
                return
            }

            # 複数件 → 一覧表示
            $results = $trkpts | ForEach-Object {
                [PSCustomObject]@{
                    拠点名 = $_.name
                    住所   = [GPXDocument]::GetTownName($_, 3)
                    緯度   = $_.lat
                    経度   = $_.lon
                    # 内部的にtrkptを保持（表示はしない）
                    _trkpt = $_
                }
            }

            $datagrid.ItemsSource = $results
        }
        catch {
            [System.Windows.MessageBox]::Show("検索処理でエラー: $($_.Exception.Message)","エラー")
        }
    }

    # ボタンクリックイベント
    $searchBtn.Add_Click($searchAction)

    # Enterキーイベント
    $textbox.Add_KeyDown({
        if ($_.Key -eq "Enter") {
            & $searchAction
        }
    })

    # DataGrid選択イベント（クリックでコピー＋ログ保存）
    $datagrid.Add_SelectionChanged({
        $selected = $datagrid.SelectedItem
        if ($selected) {
            $text = "$($selected.緯度),$($selected.経度)"
            Set-Clipboard -Value $text
            [System.Windows.MessageBox]::Show("コピーしました: $text","結果")

            if ($selected._trkpt) {
                Write-PlaceLog -FilePath $FilePath -Trkpt $selected._trkpt
            }
        }
    })

    $window.ShowDialog() | Out-Null
}

# 実行
Start-KeywordListGui