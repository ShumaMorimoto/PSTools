using module RouteOptimizer
Add-Type -AssemblyName PresentationFramework

Import-module ./New-SearchCombo.ps1


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
    $keywordBox = New-SearchCombo -Name "keyword"
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

        if (-not $keyword -or $keyword.Trim() -eq "") {
            [System.Windows.MessageBox]::Show("キーワードを入力してください", "注意")
            return
        }

        try {
            $trkpts = ([GPXDocumentFactory]::Search($keyword)).GetTrkPts()

            if (-not $trkpts -or $trkpts.Count -eq 0) {
                [System.Windows.MessageBox]::Show("検索結果が見つかりませんでした", "結果")
                $datagrid.ItemsSource = $null
                return
            }

            # 共通の表示処理
            $results = @()
            $results += $trkpts | ForEach-Object {
                [PSCustomObject]@{
                    拠点名    = $_.name
                    住所     = [GPXDocument]::GetTownName($_, 3)
                    緯度     = $_.lat
                    経度     = $_.lon
                    _trkpt = $_
                }
            }
            # 履歴を取得
            $historyEntry = $keywordBox.Tag.GetHistory.Invoke($keyword)

            # 履歴優先に並べ替え
            $results = Promote-HistoryMatches -SearchResults $results -HistoryEntry $historyEntry

            # DataGridに反映
            $datagrid.ItemsSource = $results

            if ($trkpts.Count -eq 1) {
                $trkpt = $trkpts[0]
                $text = "$($trkpt.lat),$($trkpt.lon)"
                Set-Clipboard -Value $text
                Write-PlaceLog -FilePath $FilePath -Trkpt $trkpt

                $entry = [pscustomobject]@{
                    keyword  = $keyword
                    selected = @{ lat = [double]$trkpt.lat; lon = [double]$trkpt.lon }
                }
                $keywordBox.Tag.AddHistory.Invoke($entry)

                [System.Windows.MessageBox]::Show("検索結果が1件のため自動コピーしました: $text", "結果")
            }
        }
        catch {
            [System.Windows.MessageBox]::Show("検索処理でエラー: $($_.Exception.Message)", "エラー")
        }
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
Start-KeywordListGui