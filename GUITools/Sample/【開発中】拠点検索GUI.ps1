using module D:\tool\Repository\PSTools\GUITools
using module RouteOptimizer

$FilePath = "D:\tool\log\SearchPlaceLog.gpx"

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


# ===============================
# Entry定義
# ===============================
class PlaceEntry : GUITools.EntryBase {
    [string]$名称
    [string]$住所
    [double]$緯度
    [double]$経度
    [System.Xml.XmlElement]$_trkpt

    PlaceEntry([System.Xml.XmlElement]$trkpt) {
        $this.名称 = $trkpt.name
        $this.住所 = [RouteOptimizer.GPXDocument]::GetTownName($trkpt, 3)
        $this.緯度 = [double]$trkpt.lat
        $this.経度 = [double]$trkpt.lon
        $this._trkpt = $trkpt
    }

    PlaceEntry([hashtable]$json) : base($json) { }
    PlaceEntry([pscustomobject]$json) : base($json) { }
}


# ===============================
# MainWindow とコントロール取得
# ===============================
$window = Get-GUIToolsWindow -WindowName "SRWindow"
$searchCombo = Get-GUIToolsControl -ControlName "SearchCombo"
$resultGrid = Get-GUIToolsControl -ControlName "ResultGrid"

# 差し込み
($window.FindName("SearchComboHost")).Content = $searchCombo
($window.FindName("ResultGridHost")).Content = $resultGrid

# ===============================
# ステータスバー更新（3変数版）
# ===============================
$statusText = $window.FindName("StatusText")
$SetStatus = {
    param([string]$level, [string]$component, [string]$message)
    $statusText.Text = "[$level][$component] $message"
}.GetNewClosure()

# ===============================
# コンポーネント初期化呼び出し（INIT 内で Tag.SetStatus を登録）
# ===============================
Init-SearchComboLogic -control $searchCombo -Name "Places" -EntryClass ([PlaceEntry]) -SetStatus $SetStatus
Init-ResultGridLogic  -control $resultGrid  -Name "ResultGrid"  -SetStatus $SetStatus

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
# イベント連動（必ず Tag.SetStatus を2変数で呼ぶ）
# ===============================

# SearchCombo → キーワード確定 → 検索実行 → ResultGridへ
$searchCombo.Tag.Entered = [Action[string]] {
    param($kw)

    if ([string]::IsNullOrWhiteSpace($kw)) {
        $searchCombo.Tag.SetStatus.Invoke("Warn", "キーワードが空です")
        return
    }

    $searchCombo.Tag.SetStatus.Invoke("Info", "検索中…")
    $results = Invoke-Search $kw

    & $resultGrid.Tag.SetData $results
    & $resultGrid.Tag.RefreshView @()

    $searchCombo.Tag.SetStatus.Invoke("Info", "検索完了（件数: $($results.Count)）")
}.GetNewClosure()

# ResultGrid → 拠点選択（詳細ペインはないのでステータスのみ）
# ResultGrid → 選択確定（履歴登録＋ステータス更新）
$resultGrid.Tag.Selected = {
    param($entry)   # PlaceEntry

    $text = "$($entry.緯度),$($entry.経度)"
    Set-Clipboard -Value $text

    if ($entry._trkpt) {
        Write-PlaceLog -FilePath $FilePath -Trkpt $entry._trkpt
    }
    $searchCombo.Tag.AddHistory.Invoke($searchCombo.Text,$entry)                
    $resultGrid.Tag.SetStatus.Invoke("INFO", "クリップボードにコピー: $($entry.名称) [$($entry.住所)]")
}

# ===============================
# ウィンドウ表示
# ===============================
$window.ShowDialog() | Out-Null