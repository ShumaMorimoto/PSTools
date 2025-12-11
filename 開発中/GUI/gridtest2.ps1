$text = "生年月日: {{birthday|toString('昭和')}} 名称: {{拠点名|upper}} 位置: {{緯度}},{{経度}}"

$data = [pscustomobject]@{
    birthday = "1970-05-01"
    拠点名   = "横須賀拠点"
    緯度     = "35.0"
    経度     = "139.7"
}

$TemplateFunctions = @{
    "toString" = {
        param($date,$prefix)
        $y = (Get-Date $date).Year - 1925
        "$prefix$y年"
    }
    "upper" = {
        param($value)
        $value.ToUpper()
    }
}

$matches = [regex]::Matches($text, "{{(.*?)}}")

foreach ($m in $matches) {
    $expr = $m.Groups[1].Value.Trim()
    $prop = ([regex]::Match($expr, "^\s*([^\|]+)")).Groups[1].Value
    $raw  = $data.$prop

    $funcName = ([regex]::Match($expr, "\|(\w+)")).Groups[1].Value
    if ($funcName) {
        $args = @()
        $argMatch = [regex]::Match($expr, "\((.*?)\)")
        if ($argMatch.Success) {
            $rawArgs = $argMatch.Groups[1].Value
            $args = $rawArgs -split ","
            $args = $args | ForEach-Object {
                $s = $_.Trim()
                if ($s -match "^'(.*)'$") { $s = $Matches[1] }
                elseif ($s -match '^"(.*)"$') { $s = $Matches[1] }
                $s
            }
        }
        $raw = & $TemplateFunctions[$funcName] $raw @args
    }

    $text = $text.Replace($m.Value, [string]$raw)
}

$text