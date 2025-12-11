# --- 関数テーブル定義（モジュール側想定） ---
$TemplateFunctions = @{
    "toString" = {
        param($date,$prefix)
        $y = (Get-Date $date).Year - 1925
        return "$prefix$y年"
    }
    "upper" = {
        param($value)
        return $value.ToUpper()
    }
}

function Convert-ByTemplate {
    param(
        [hashtable]$Template,
        [psobject]$Entry
    )

    $result = @{}

    foreach ($tpl in $Template.GetEnumerator()) {
        $value = [string]$tpl.Value

        # --- {{...}} を最短一致で抽出 ---
        $matches = [regex]::Matches($value, "{{(.*?)}}")

        foreach ($m in $matches) {
            $expr = $m.Groups[1].Value.Trim()  # 例: birthday|toString('昭和')

            $parts = $expr -split "\|"
            $prop  = $parts[0].Trim()
            $raw   = $Entry.$prop

            if ($parts.Count -gt 1) {
                $funcExpr = $parts[1]
                $funcName, $argStr = $funcExpr -split "\(",2
                $funcName = $funcName.Trim()
                $args = @()
                if ($argStr) {
                    $argStr = $argStr.TrimEnd(")")
                    $args = $argStr -split ","
                    $args = $args | ForEach-Object { $_.Trim(" '""") }
                }

                if ($TemplateFunctions.ContainsKey($funcName)) {
                    $raw = & $TemplateFunctions[$funcName] $raw @args
                }
            }

            # $m.Value を直接置換するのが安全
            $value = $value.Replace($m.Value, [string]$raw)
        }

        $result[$tpl.Key] = $value
    }

    return $result
}

# --- テンプレート（埋め込み版） ---
$tpl = @{
    "生年月日" = "{{birthday|toString('昭和')}}"
    "名称"     = "{{拠点名|upper}}"
    "位置"     = "{{緯度}},{{経度}}"
}

# --- 入力データ ---
$data = [pscustomobject]@{
    birthday = "1970-05-01"
    拠点名   = "横須賀拠点"
    緯度     = "35.0"
    経度     = "139.7"
}

# --- 変換実行 ---
$result = Convert-ByTemplate -Template $tpl -Entry $data
$result | ConvertTo-Json -Depth 3