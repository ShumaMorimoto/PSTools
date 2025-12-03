#using module RouteOptimizer
Add-Type -AssemblyName PresentationFramework

function Promote-HistoryMatches {
    param(
        [array]$SearchResults,
        [psobject]$HistoryEntry
    )

    if (-not $HistoryEntry) { return $SearchResults }

    $priority = @()
    $others = @()

    foreach ($r in $SearchResults) {
        $match = $HistoryEntry.selected | Where-Object {
            Compare-PsObject $_ @{ lat = $r.緯度; lon = $r.経度 }
        }
        if ($match) {
            $priority += $r
        }
        else {
            $others += $r
        }
    }

    return $priority + $others
}


function Start-ProjectListGui {
    param([string]$FilePath = "D:\tool\log\SearchPlaceLog.gpx")

    $window = New-Object Windows.Window
    $window.Title = "Place Search Tool"
    $window.Width = 600
    $window.Height = 600

    $stack = New-Object Windows.Controls.StackPanel
    $stack.Margin = "10"
    $window.Content = $stack

    # ラベル
    $label = New-Object Windows.Controls.Label
    $label.Content = "キーワードを入力してください:"
    $label.FontSize = 18
    $stack.Children.Add($label)

    # キーワード入力用 ComboBox（New-SearchComboを利用）
    $keywordBox = New-SearchCombo -Name "projects"
    $stack.Children.Add($keywordBox)

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
    $datagrid.Height = 400
    $datagrid.FontSize = 16
    $stack.Children.Add($datagrid)

    # 検索処理
    $searchAction = {
        param($keyword)
        $projects = $keywordBox.TAG.GetHistory.Invoke($keyword).selected

        $results = @()
        $results += $projects | ForEach-Object {
            [PSCustomObject]@{
                実施日   = $_.実施日
                時間    = $_.時間
                ステータス = $_.ステータス
                種別    = $_.種別
            }
        }
        # DataGridに反映
        $datagrid.ItemsSource = $results
    }

    # Entered に検索アクションを登録
    $keywordBox.Tag.Entered = {
        param($kw)
        & $searchAction $kw
    }

    # ボタンクリックで検索
    $searchBtn.Add_Click({ & $searchAction $keywordBox.Text })

    # DataGrid選択イベント（クリックでコピー＋ログ保存＋履歴追加）
    $datagrid.Add_SelectionChanged({
            $selected = $datagrid.SelectedItem
            if ($selected) {
                $text = "$($selected.緯度),$($selected.経度)"
                Set-Clipboard -Value $text
                [System.Windows.MessageBox]::Show("コピーしました: $text", "結果")

                if ($selected._trkpt) {
                    Write-PlaceLog -FilePath $FilePath -Trkpt $selected._trkpt
                    $entry = [pscustomobject]@{
                        keyword  = $keywordBox.Text
                        selected = @{ lat = [double]$selected.緯度; lon = [double]$selected.経度 }
                    }
                    $keywordBox.Tag.AddHistory.Invoke($entry)                
                }
            }
        })

    $window.ShowDialog() | Out-Null
}

# 実行
Start-ProjectListGUI
