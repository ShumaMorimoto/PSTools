using module D:\tool\Repository\PSTools\GUITools
using module RouteOptimizer

# SRDWindowで定義したTESTEntryではなく、拠点検索用のPlaceEntryを利用
class PlaceEntry : GUITools.EntryBase {
    [string]$名称
    [string]$住所
    [double]$緯度
    [double]$経度

    PlaceEntry([System.Xml.XmlElement]$trkpt) {
        $this.名称 = $trkpt.name
        $this.住所 = [RouteOptimizer.GPXDocument]::GetTownName($trkpt, 3)
        $this.緯度 = [double]$trkpt.lat
        $this.経度 = [double]$trkpt.lon
    }

    PlaceEntry([object]$json) : base($json) { }
}

# ===============================
# UIロード
# ===============================
$window = Get-GUIToolsWindow -WindowName "SRWindow"
$searchCombo = Get-GUIToolsControl -ControlName "SearchCombo"
$resultGrid = Get-GUIToolsControl -ControlName "ResultGrid"

($window.FindName("SearchComboHost")).Content = $searchCombo
($window.FindName("ResultGridHost")).Content = $resultGrid

# ===============================
# ステータスバー更新関数
# ===============================
$statusText = $window.FindName("StatusText")
function Set-Status([string]$msg) { $statusText.Text = $msg }

# ===============================
# コンポーネント初期化
# ===============================
Init-SearchComboLogic -control $searchCombo -Name "SearchCombo" -SetStatus { param($l, $c, $m) Set-Status "[$l][$c] $m" }
Init-ResultGridLogic  -control $resultGrid  -Name "ResultGrid"  -SetStatus { param($l, $c, $m) Set-Status "[$l][$c] $m" }

# ===============================
# 拠点検索（PlaceEntry[] を返す）
# ===============================
function Invoke-Search([string]$keyword) {
    if ([string]::IsNullOrWhiteSpace($keyword)) { return @() }

    try {
        $trkpts = ([RouteOptimizer.GPXDocumentFactory]::Search($keyword)).GetTrkPts()
        if (-not $trkpts -or $trkpts.Count -eq 0) { return @() }

        return @(foreach ($t in $trkpts) { [PlaceEntry]::new($t) })
    }
    catch {
        Set-Status "検索エラー: $($_.Exception.Message)"
        return @()
    }
}

# ===============================
# イベント連動
# ===============================

# SearchCombo → 検索 → ResultGrid 反映
$searchCombo.Tag.Entered = [Action[string]] {
    param($kw)
    $results = Invoke-Search $kw      # PlaceEntry[]
    & $resultGrid.Tag.SetData $results
    & $resultGrid.Tag.RefreshView @()
    $searchCombo.Tag.SetStatus.Invoke("INFO", $searchCombo.Tag.Component, "検索完了（件数: $($results.Count)）")

}.GetNewClosure()

# ResultGrid → 選択確定（履歴登録＋ステータス更新）
$resultGrid.Tag.Selected = {
    param($entry)   # PlaceEntry
    $resultGrid.Tag.SetStatus.Invoke("INFO", $resultGrid.Tag.Component, "選択: $($entry.名称) [$($entry.住所)]")
    $searchCombo.Tag.AddHistory.Invoke($searchCombo.Text, $entry)

}.GetNewClosure()

# ===============================
# ウィンドウ表示
# ===============================
$window.ShowDialog() | Out-Null