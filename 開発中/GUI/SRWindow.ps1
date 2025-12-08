using module D:\tool\Repository\PSTools\GUITools

# ===============================
# テスト用 Entry クラス
# ===============================
class TESTEntry : EntryBase {
    [string]$名称
    [string]$住所
    [string]$Keyword

    TESTEntry([string]$name, [string]$addr, [string]$kw) {
        $this.名称 = $name
        $this.住所 = $addr
        $this.Keyword = $kw
    }

    [bool] Equals([object]$obj) {
        if ($null -eq $obj) { return $false }
        if (-not ($obj -is [TESTEntry])) { return $false }
        return ($this.Keyword -eq $obj.Keyword -and
            $this.名称 -eq $obj.名称 -and
            $this.住所 -eq $obj.住所)
    }

    [int] GetHashCode() {
        return ($this.Keyword + $this.名称 + $this.住所).GetHashCode()
    }

    [string] ToString() {
        return "$($this.名称) [$($this.住所)]"
    }
}

# ===============================
# MainWindow を取得
# ===============================
$window = Get-GUIToolsWindow -WindowName "SRWindow"
$searchCombo = Get-GUIToolsControl -ControlName "SearchCombo"
$resultGrid = Get-GUIToolsControl -ControlName "ResultGrid"

# 差し込み
($window.FindName("SearchComboHost")).Content = $searchCombo
($window.FindName("ResultGridHost")).Content = $resultGrid

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

Init-SearchComboLogic -control $searchCombo -Name "SearchCombo" -EntryClass ([TESTEntry]) -SetStatus $SetStatus
Init-ResultGridLogic  -control $resultGrid  -Name "ResultGrid"  -SetStatus $SetStatus

# ===============================
# 検索ロジック（ダミー）
# ===============================
function Invoke-Search([string]$keyword) {
    $results = @(
        [TESTEntry]::new("ダミー拠点1", "東京都千代田区", $keyword),
        [TESTEntry]::new("ダミー拠点2", "東京都港区", $keyword),
        [TESTEntry]::new("ダミー拠点3", "東京都新宿区", $keyword)
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

    $results = Invoke-Search $kw

    & $resultGrid.Tag.SetData $results
    & $resultGrid.Tag.RefreshView @()

    $searchCombo.Tag.SetStatus.Invoke("Info", $searchCombo.Tag.Component, "検索完了（件数: $($results.Count)）")
 
}.GetNewClosure()

# ResultGrid → 拠点選択（詳細ペインはないのでステータスのみ）
$resultGrid.Tag.Selected = {
    param($entry)
    $resultGrid.Tag.SetStatus.Invoke("Info", $resultGrid.Tag.Component, "選択: $($entry.名称) [$($entry.住所)]")
}.GetNewClosure()

# ===============================
# ウィンドウ表示
# ===============================
$window.ShowDialog() | Out-Null