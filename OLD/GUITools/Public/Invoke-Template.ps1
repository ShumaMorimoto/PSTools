# ===== デフォルトの関数テーブル（同一 ps1 内） =====
# スクリプトスコープに置いて、未指定時のデフォルトとして使う
$script:DefaultFuncTable = @{
    "toString" = {
        param($date, $prefix)
        $y = (Get-Date $date).Year - 1925
        "$prefix${y}年"
    }
    "upper" = {
        param($value)
        $value.ToUpper()
    }
}

# ===== テンプレート展開関数（FuncTable 未指定ならデフォルト） =====
function Invoke-Template {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Template,

        [Parameter(Mandatory=$true)]
        [psobject]$Data,

        # 未指定なら同一 ps1 内の $script:DefaultFuncTable を使用
        [hashtable]$FuncTable = $script:DefaultFuncTable
    )

    $matches = [regex]::Matches($Template, "{{(.*?)}}")

    foreach ($m in $matches) {
        $expr = $m.Groups[1].Value.Trim()

        # プロパティ名を抽出し、値を取得
        $prop = ([regex]::Match($expr, "^\s*([^\|]+)")).Groups[1].Value
        $raw  = $Data.$prop

        # 関数名を抽出
        $funcName = ([regex]::Match($expr, "\|(\w+)")).Groups[1].Value

        if ($funcName) {
            # 引数抽出（括弧内）
            $args = @()
            $argMatch = [regex]::Match($expr, "\((.*?)\)")
            if ($argMatch.Success) {
                $rawArgs = $argMatch.Groups[1].Value
                # split → trim → クォート除去 → 必ず配列化
                $args = ,@($rawArgs -split "," | ForEach-Object {
                    $s = $_.Trim()
                    $s -replace "^'(.*)'$", '$1' -replace '^"(.*)"$', '$1'
                })
            }

            # 関数テーブルから呼び出し（未実装なら明確にエラー）
            if (-not $FuncTable.ContainsKey($funcName)) {
                throw "FuncTable に '$funcName' が登録されていません。"
            }
            $raw = & $FuncTable[$funcName] $raw @args
        }

        # プレースマーカ置換
        $Template = $Template.Replace($m.Value, [string]$raw)
    }

    return $Template
}