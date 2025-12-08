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
# SRDWindow ロード
# ===============================
$window      = Get-GUIToolsWindow -WindowName "SRDWindow"
$searchCombo = Get-GUIToolsControl -ControlName "SearchCombo"
$resultGrid  = Get-GUIToolsControl -ControlName "ResultGrid"
$detailGrid  = Get-GUIToolsControl -ControlName "DetailGrid"

($window.FindName("SearchComboHost")).Content = $searchCombo
($window.FindName("ResultGridHost")).Content  = $resultGrid
($window.FindName("DetailGridHost")).Content  = $detailGrid

# ===============================
# ステータスバー更新
# ===============================
$statusText = $window.FindName("StatusText")
function Set-Status([string]$msg) { $statusText.Text = $msg }
$SetStatus = { param($l,$c,$m) Set-Status "[$l][$c] $m" }

# ===============================
# コンポーネント初期化
# ===============================
Init-SearchComboLogic -control $searchCombo -Name "Projects" -EntryClass ([ProjectEntry]) -SetStatus $SetStatus
Init-ResultGridLogic  -control $resultGrid  -Name "ResultGrid"  -SetStatus $SetStatus
Init-DetailGridLogic  -control $detailGrid  -Name "DetailGrid"  -SetStatus $SetStatus

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
        Set-Status "履歴検索エラー: $($_.Exception.Message)"
        return @()
    }
}

# ===============================
# イベント連動
# ===============================

# SearchCombo → 履歴検索 → ResultGridへ
$searchCombo.Tag.Entered = [Action[string]] {
    param($kw)
    Set-Status "履歴検索中…"
    $results = Invoke-Search $kw
    & $resultGrid.Tag.SetData $results
    & $resultGrid.Tag.RefreshView @()
    Set-Status "履歴検索完了（件数: $($results.Count)）"
}.GetNewClosure()

# ResultGrid → 選択 → DetailGridへ ＋ 履歴追加
$resultGrid.Tag.Selected = {
    param($entry)
    if (-not $entry) { return }
    & $detailGrid.Tag.SetData $entry
    Set-Status "選択 → 詳細表示: $($entry.タイトル)"
    $searchCombo.Tag.AddHistory.Invoke($searchCombo.Text, $entry)
}.GetNewClosure()

# DetailGrid → Entered: 選択中の Items 全部をクリップボードにコピー
$detailGrid.Tag.Entered = {
    param($entries)
    if (-not $entries -or $entries.Count -eq 0) {
        Set-Status "詳細グリッドに選択がありません"
        return
    }
    $lines = foreach ($e in $entries) {
        "項番:$($e.項番) 実施日:$($e.実施日) 場所:$($e.場所) タイトル:$($e.タイトル)"
    }
    $text = ($lines -join "`r`n")
    try {
        Set-Clipboard -Value $text
        [System.Windows.MessageBox]::Show("コピーしました:`r`n$text", "詳細") | Out-Null
    } catch { }
    Set-Status "詳細コピー完了（件数: $($entries.Count)）"
}.GetNewClosure()

# ===============================
# ウィンドウ表示
# ===============================
$window.ShowDialog() | Out-Null