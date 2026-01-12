using module D:\tool\Repository\PSTools\GUITools

# ===============================
# テスト用 Entry クラス
# ===============================
class TESTEntry : EntryBase {
    [string]$名称
    [string]$住所
    [string]$Keyword

    # 既存の文字列コンストラクタ
    TESTEntry([string]$name, [string]$addr, [string]$kw) {
        $this.名称    = $name
        $this.住所    = $addr
        $this.Keyword = $kw
    }

    # PSObject コンストラクタを追加して EntryBase 側の処理に委譲
    TESTEntry([psobject]$json) : base($json) { }

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

# ===============================
# MainWindow とコントロール取得
# ===============================
$window     = Get-GUIToolsWindow -WindowName "SRDWindow"
$searchCombo = Get-GUIToolsControl -ControlName "SearchCombo"
$resultGrid  = Get-GUIToolsControl -ControlName "ResultGrid"
$detailList  = Get-GUIToolsControl -ControlName "DetailList"

# 差し込み
($window.FindName("SearchComboHost")).Content = $searchCombo
($window.FindName("ResultGridHost")).Content  = $resultGrid
($window.FindName("DetailListHost")).Content  = $detailList

# ===============================
# ステータスバー更新（3変数版）
# ===============================
$statusText = $window.FindName("StatusText")
$SetStatus = {
    param([string]$level,[string]$component,[string]$message)
    $statusText.Text = "[$level][$component] $message"
}.GetNewClosure()

# ===============================
# コンポーネント初期化呼び出し
# ===============================
Init-SearchComboLogic -control $searchCombo -Name "SearchCombo" -EntryClass ([TestEntry]) -SetStatus $SetStatus
Init-ResultGridLogic  -control $resultGrid  -Name "ResultGrid"  -SetStatus $SetStatus
Init-DetailListLogic  -control $detailList  -Name "DetailList"  -SetStatus $SetStatus

# ===============================
# 検索ロジック（ダミー）
# ===============================
function Invoke-Search([string]$keyword) {
    $results = @(
        [TESTEntry]::new("ダミー拠点1", "東京都千代田区", $keyword),
        [TESTEntry]::new("ダミー拠点2", "東京都港区",   $keyword)
    )
    return $results
}

# ===============================
# イベント連動
# ===============================

# SearchCombo → キーワード確定 → 検索実行 → ResultGridへ
$searchCombo.Tag.Entered = [Action[string]] {
    param($kw)

    if ([string]::IsNullOrWhiteSpace($kw)) {
        $searchCombo.Tag.SetStatus.Invoke("Warn","キーワードが空です")
        return
    }

    $searchCombo.Tag.SetStatus.Invoke("Info","検索中…")
    $results = Invoke-Search $kw

    & $resultGrid.Tag.SetData $results
    & $resultGrid.Tag.RefreshView @()

    $searchCombo.Tag.SetStatus.Invoke("Info","検索完了（件数: $($results.Count)）")
}.GetNewClosure()

# ResultGrid → 拠点選択 → DetailListへ ＋ SearchCombo履歴追加
$resultGrid.Tag.Selected = {
    param($entry)

    & $detailList.Tag.SetData $entry
    $resultGrid.Tag.SetStatus.Invoke("Info","拠点選択 → 詳細表示")

    if ($entry.Keyword) {
        & $searchCombo.Tag.AddHistory $entry.Keyword $entry
        $resultGrid.Tag.SetStatus.Invoke("Info","履歴追加: $($entry.Keyword)")
    }
}.GetNewClosure()

# DetailList → 詳細確定（必要なら有効化）
#$detailList.Tag.Entered = {
#    param($entry)
#    $detailList.Tag.SetStatus.Invoke("Info","詳細表示完了: $($entry.名称)")
#}.GetNewClosure()

# ===============================
# ウィンドウ表示
# ===============================
$window.ShowDialog() | Out-Null