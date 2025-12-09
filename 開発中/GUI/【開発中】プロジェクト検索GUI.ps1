using module D:\tool\Repository\PSTools\GUITools

# ===============================
# ProjectEntry クラス
# ===============================
class ProjectEntry : EntryBase {
    [string]$実施日
    [string]$時間
    [string]$ステータス
    [string]$種別
    [string]$顧客略号
    [string]$タイトル
    [string]$ランク
    [string]$PW担当
    [string]$担当部
    [string]$PM
    [string]$P責

    ProjectEntry([object]$json) : base($json) {
        $this.実施日 = $json.実施日
        $this.時間 = $json.時間
        $this.ステータス = $json.ステータス
        $this.顧客略号 = $json.顧客略号
        $this.タイトル = $json.タイトル
        $this.ランク = $json.ランク
        $this.PW担当 = $json.PW担当
        $this.種別 = $json.種別
        $this.担当部 = $json.担当部
        $this.PM = $json.PM
        $this.P責 = $json.P責
    }

    [bool] Equals([object]$obj) {
        if ($null -eq $obj) { return $false }
        if (-not ($obj -is [ProjectEntry])) { return $false }
        return ($this.タイトル -eq $obj.タイトル -and
                $this.実施日 -eq $obj.実施日)
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
Init-SearchComboLogic -control $searchCombo -Name "Projects" -EntryClass ([ProjectEntry]) -SetStatus $SetStatus
Init-ResultGridLogic  -control $resultGrid  -Name "ResultGrid"  -SetStatus $SetStatus
Init-DetailListLogic  -control $detailList  -Name "DetailList"  -SetStatus $SetStatus

# ===============================
# 履歴検索（GetHistoryの戻りは keyword+ProjectEntry×N）
# ===============================
function Invoke-Search([string]$keyword) {
    if ([string]::IsNullOrWhiteSpace($keyword)) { return @() }

    try {
        $historyEntry = $searchCombo.Tag.GetHistory.Invoke($keyword)
        if (-not $historyEntry) { return @() }

        # selected は ProjectEntry の配列
        return @(foreach ($e in $historyEntry.selected) {
            if ($e -is [ProjectEntry]) { $e }
            else { [ProjectEntry]::new($e) }
        })
    }
    catch {
        & $searchCombo.Tag.SetStatus "ERROR" "履歴検索エラー: $($_.Exception.Message)"
        return @()
    }
}

# ===============================
# イベント連動
# ===============================
$searchCombo.Tag.Entered = [Action[string]] {
    param($kw)
    $searchCombo.Tag.SetStatus.Invoke("Info","検索中…")
    $results = Invoke-Search $kw
    & $resultGrid.Tag.SetData $results
    & $resultGrid.Tag.RefreshView @()
    $searchCombo.Tag.SetStatus.Invoke("Info","検索完了（件数: $($results.Count)）")
}.GetNewClosure()

# ResultGrid → 選択 → detailListへ ＋ 履歴追加
$resultGrid.Tag.Selected = {
    param($entry)
    if (-not $entry) { return }

    & $detailList.Tag.SetData $entry
    $resultGrid.Tag.SetStatus.Invoke("Info","選択 → 詳細表示: $($entry.タイトル)")
    $searchCombo.Tag.AddHistory.Invoke($searchCombo.Text, $entry)
}.GetNewClosure()

# detailList → Entered: 選択中の Items 全部をクリップボードにコピー
# DetailList → 詳細確定（必要なら有効化）
#$detailList.Tag.Entered = {
#    param($entry)
#    $detailList.Tag.SetStatus.Invoke("Info","詳細表示完了: $($entry.名称)")
#}.GetNewClosure()

# ===============================
# ウィンドウ表示
# ===============================
$window.ShowDialog() | Out-Null