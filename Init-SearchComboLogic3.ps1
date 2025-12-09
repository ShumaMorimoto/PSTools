# ===================================================================
# INIT-SearchComboLogic 関数 (完成版)
# IMEの確定Enterと検索実行Enterを判別するロジックをComboBoxに適用する
# ===================================================================

# イベントハンドラ間でテキストを共有するためのスクリプトスコープ変数
$script:TextBeforeEnter = $null

function INIT-SearchComboLogic {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.ComboBox]$Control,

        [Parameter(Mandatory=$true)]
        [scriptblock]$OnEnterAction
    )

    # ----------------------------------------------------
    # KeyDownイベント: Enterキーが押された"直前"のテキストを保存
    # ----------------------------------------------------
    $Control.Add_KeyDown({
        param($sender, $e)

        # 押されたキーがEnterでなければ何もしない
        if ($e.Key -ne [System.Windows.Input.Key]::Return) { return }

        # Enterキーが押された瞬間のテキストをスクリプトスコープの変数に保存
        $script:TextBeforeEnter = $sender.Text
    }.GetNewClosure())

    # ----------------------------------------------------
    # KeyUpイベント: Enterキーが離された"直後"に判定と実行
    # ----------------------------------------------------
    $Control.Add_KeyUp({
        param($sender, $e)

        # 離されたキーがEnterでなければ何もしない
        if ($e.Key -ne [System.Windows.Input.Key]::Return) { return }

        # 【最重要ロジック】
        # KeyDownで保存したテキストと現在のテキストを比較する。
        # もしテキストが変化していれば、それはIMEの変換が確定した結果なので、
        # アクションを実行せずに処理を終了する。
        if ($sender.Text -ne $script:TextBeforeEnter) {
            # (任意) IME確定のログを出力
            Add-Log "[KeyUp]   IME確定Enterと判断。アクションは実行しません。"
            return
        }

        # テキストに変化がなければ、それは「検索実行」のためのEnterと判断。
        # 引数で渡されたアクション($OnEnterAction)を実行する。
        Add-Log "[KeyUp]   検索実行Enterと判断。アクションを実行します。"
        & $OnEnterAction

    }.GetNewClosure())
}
