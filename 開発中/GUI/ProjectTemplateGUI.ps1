# GUIのために必要なアセンブリを読み込む
Add-Type -AssemblyName PresentationFramework

# -----------------------------------------------------------------
# Helper Function: テンプレート文字列を展開する関数
# -----------------------------------------------------------------
function Expand-TemplateString {
    param(
        [string]$TemplateString,
        [psobject]$DataObject
    )

    # 特殊なテンプレートタグを先に処理
    # <json>: オブジェクトをJSON文字列に変換
    if ($TemplateString -eq '<json>') {
        return $DataObject | ConvertTo-Json -Depth 5 -Compress
    }
    # <clipboard>: 現在のクリップボードの内容を取得
    if ($TemplateString -eq '<clipboard>') {
        return Get-Clipboard
    }
    # <資料パス>: プロジェクト名からダミーのパスを生成
    if ($TemplateString -eq '<資料パス>') {
        return "\\fileserver\share\projects\$($DataObject.タイトル)"
    }
    
    # <key> 形式のプレースホルダを正規表現で探し、データで置換する
    $expandedString = [regex]::Replace($TemplateString, '<(.+?)>', {
            param($match)
            $key = $match.Groups[1].Value

            # 特殊な組み合わせのキーを処理 ('<実施日_曜日>' など)
            if ($key -eq '実施日_曜日') {
                return "$($DataObject.実施日)$($DataObject.曜日)"
            }
        
            # データオブジェクトにプロパティが存在すればその値を、なければ空文字を返す
            if ($DataObject.PSObject.Properties.Match($key).Count -gt 0) {
                return $DataObject.$key
            }
            else {
                return "" # データがない場合は空文字に置換
            }
        })

    return $expandedString
}

# -----------------------------------------------------------------
# Main Function: テンプレート結果を表示するGUIダイアログ
# -----------------------------------------------------------------
function Show-TemplateDialog {
    param(
        [psobject]$ProjectData
    )

    # --- 1. テンプレートの定義 (オンコード) ---
    $templates = @(
        [pscustomobject]@{ テンプレート名 = "案内"; フォーマット = "<実施日_曜日> <時間> <顧客略号> <タイトル>（<ランク>：<種別>）" },
        [pscustomobject]@{ テンプレート名 = "資料フォルダ"; フォーマット = "<資料パス>" },
        [pscustomobject]@{ テンプレート名 = "設計会議情報"; フォーマット = "<json>" },
        [pscustomobject]@{ テンプレート名 = "クリップボード"; フォーマット = "<clipboard>" }
    )

    # --- 2. テンプレートに基づいてテキストを生成 ---
    $results = foreach ($template in $templates) {
        [pscustomobject]@{
            テンプレート名 = $template.テンプレート名
            内容      = Expand-TemplateString -TemplateString $template.フォーマット -DataObject $ProjectData
        }
    }

    # --- 3. GUIの作成 ---
    $dialog = New-Object Windows.Window
    $dialog.Title = "テンプレートからコピー"
    $dialog.Width = 600
    $dialog.Height = 350
    $dialog.WindowStartupLocation = "CenterScreen" # 画面中央に表示

    $grid = New-Object Windows.Controls.Grid
    $grid.Margin = "10"
    $dialog.Content = $grid
    
    $dataGrid = New-Object Windows.Controls.DataGrid
    $dataGrid.ItemsSource = $results
    $dataGrid.IsReadOnly = $true # 読み取り専用
    $dataGrid.FontSize = 14
    $dataGrid.HeadersVisibility = "Column"
    $dataGrid.CanUserAddRows = $false # ユーザーが行を追加できないようにする
    
    # ▼▼▼▼▼ ここを修正しました ▼▼▼▼▼
    # Loadedイベントに関数を登録して、列幅を自動調整
    $dataGrid.Add_Loaded({
            $dataGrid.Columns[0].Width = [System.Windows.Controls.DataGridLength]::new(150) # 'テンプレート名'列の幅を固定
            $dataGrid.Columns[1].Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Star) # '内容'列は残りの幅をすべて使用
        })
    # ▲▲▲▲▲ 修正ここまで ▲▲▲▲▲

    $grid.Children.Add($dataGrid)

    # --- 4. イベントハンドラの設定 (ダブルクリックでコピー) ---
    $dataGrid.Add_MouseDoubleClick({
            $selectedItem = $dataGrid.SelectedItem
            if ($selectedItem) {
                Set-Clipboard -Value $selectedItem.内容
                # 確認メッセージを表示
                [System.Windows.MessageBox]::Show("`"$($selectedItem.テンプレート名)`" の内容をコピーしました。", "コピー完了", "OK", "Information")
                # ダイアログを閉じる
                $dialog.Close()
            }
        })

    # --- 5. ダイアログの表示 ---
    $dialog.ShowDialog() | Out-Null
}

# -----------------------------------------------------------------
# 実行部分
# -----------------------------------------------------------------

# 1. サンプルのプロジェクトデータを作成
$sampleProject = [pscustomobject]@{
    項番            = 11.0
    実施日           = "4/21(4/17-18)"
    曜日            = "金"
    時間            = "10:00-11:30"
    会議時間          = 90.0
    場所            = "zoom会議"
    ステータス         = "実施"
    本部            = "産業"
    顧客略号          = "EOO"
    タイトル          = "人材見える化システム構築"
    優先度           = $null
    ランク           = "B"
    AIリスク         = $null
    部レビュー         = "？"
    アーキテクチャーレビュー  = "－"
    "(産ソリ)本部案件会議" = "－"
    開発会議          = "－"
    案件会議          = "－"
    PW担当          = "森本"
    種別            = "提案・見積"
    次Ph提案レビュー     = $null
    再審議           = $null
    担当部           = "産二 or産四"
    PM            = "検討中"
    P責            = $null
}

# 2. 関数を呼び出してGUIを表示
Write-Host "GUIウィンドウを表示します..."
Show-TemplateDialog -ProjectData $sampleProject
Write-Host "GUIウィンドウを閉じました。"
