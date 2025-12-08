using module D:\tool\Repository\PSTools\GUITools

# ===============================
# テスト用 Entry クラス
# ===============================
class TESTEntry : EntryBase {
    [string]$名称
    [string]$住所
    [string]$Keyword

    TESTEntry([string]$name, [string]$addr, [string]$kw) {
        $this.名称    = $name
        $this.住所    = $addr
        $this.Keyword = $kw
    }

    [bool] Equals([object]$obj) {
        if ($null -eq $obj) { return $false }
        if (-not ($obj -is [TESTEntry])) { return $false }
        return ($this.Keyword -eq $obj.Keyword -and
                $this.名称    -eq $obj.名称    -and
                $this.住所    -eq $obj.住所)
    }

    [int] GetHashCode() {
        return ($this.Keyword + $this.名称 + $this.住所).GetHashCode()
    }
}

# MainWindow を取得
$window = Get-GUIToolsWindow -WindowName "SRDWindow"

# Controls.xaml から必要なコンポーネントを取得
$searchCombo = Get-GUIToolsControl -ControlName "SearchCombo"
$resultGrid  = Get-GUIToolsControl -ControlName "ResultGrid"
$detailList  = Get-GUIToolsControl -ControlName "DetailList"   # ← DetailGridではなくDetailListを取得

# 差し込み
($window.FindName("SearchComboHost")).Content = $searchCombo
($window.FindName("ResultGridHost")).Content  = $resultGrid
($window.FindName("DetailGridHost")).Content  = $detailList   # ← Hostはそのまま利用

# ===============================
# ステータスバー更新関数
# ===============================
$statusText = $window.FindName("StatusText")
function Set-Status([string]$msg) {
    $statusText.Text = $msg
}

# ===============================
# コンポーネント初期化呼び出し
# ===============================
$SetStatus = { param($l, $c, $m) Set-Status "[$l][$c] $m" }

Init-SearchComboLogic -control $searchCombo -Name "SearchCombo" -EntryClass ([TestEntry]) -SetStatus $SetStatus
Init-ResultGridLogic  -control $resultGrid  -Name "ResultGrid"  -SetStatus $SetStatus
Init-DetailListLogic  -control $detailList  -Name "DetailList"  -SetStatus $SetStatus   # ← Grid版からList版へ変更

# ===============================
# 検索ロジック（ダミー）
# ===============================
function Invoke-Search([string]$keyword) {
    $results = @(
        [TESTEntry]::new("ダミー拠点1", "東京都千代田区", $keyword),
        [TESTEntry]::new("ダミー拠点2", "東京都港区",   $keyword)
    )
    return , $results
}

# ===============================
# イベント連動
# ===============================

# SearchCombo → キーワード確定 → 検索実行 → ResultGridへ
$searchCombo.Tag.Entered = [Action[string]] {
    param($kw)

    if ([string]::IsNullOrWhiteSpace($kw)) {
        Set-Status "キーワードが空です"
        return
    }

    Set-Status "検索中…"
    $results = Invoke-Search $kw

    & $resultGrid.Tag.SetData $results
    & $resultGrid.Tag.RefreshView @()

    Set-Status "検索完了（件数: $($results.Count)）"
}.GetNewClosure()

# ResultGrid → 拠点選択 → DetailListへ ＋ SearchCombo履歴追加
$resultGrid.Tag.Selected = {
    param($entry)

    & $detailList.Tag.SetData $entry   # ← DetailGridではなくDetailListへ
    Set-Status "拠点選択 → 詳細表示"

    if ($entry.Keyword) {
        & $searchCombo.Tag.AddHistory $entry.Keyword $entry
        Set-Status "履歴追加: $($entry.Keyword)"
    }
}.GetNewClosure()

# DetailList → 詳細確定
#$detailList.Tag.Entered = {
#    param($entry)
#    Set-Status "詳細表示完了: $($entry.名称)"
#}.GetNewClosure()

# ===============================
# ウィンドウ表示
# ===============================
$window.ShowDialog() | Out-Null