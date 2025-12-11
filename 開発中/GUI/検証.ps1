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
        "$prefix${y}年"
    }
    "upper" = {
        param($value)
        $value.ToUpper()
    }
}

$matches = [regex]::Matches($text, "{{(.*?)}}")

foreach ($m in $matches) {
    $expr = $m.Groups[1].Value.Trim()
    Write-Host "---- expr=[$expr]"

    $prop = ([regex]::Match($expr, "^\s*([^\|]+)")).Groups[1].Value
    $raw  = $data.$prop
    Write-Host "prop=[$prop] raw=[$raw]"

    $funcName = ([regex]::Match($expr, "\|(\w+)")).Groups[1].Value
    Write-Host "funcName=[$funcName]"

    if ($funcName) {
        $args = @()
        $argMatch = [regex]::Match($expr, "\((.*?)\)")
        Write-Host "argMatch.Success=[$($argMatch.Success)] argMatch.Value=[$($argMatch.Value)]"

        if ($argMatch.Success) {
            $rawArgs = [string]$argMatch.Groups[1].Value
            Write-Host "rawArgs=[$rawArgs]"

            $args = $rawArgs -split ","
            foreach ($a in $args) { Write-Host "args(before)=[$a]" }

            $args = $args | ForEach-Object {
                $s = $_.Trim()
                $before = $s
                $s = $s -replace "^'(.*)'$", '$1'
                $s = $s -replace '^"(.*)"$', '$1'
                Write-Host "  unquote: in=[$before] out=[$s]"
                $s
            }
            Write-Host "args(final)=[${args -join ' | '}]"
        }

        $raw = & $TemplateFunctions[$funcName] $raw $args
        Write-Host "invoke result=[$raw]"
    }

    $text = $text.Replace($m.Value, [string]$raw)
    Write-Host "replace: token=[$($m.Value)] -> [$raw]"
}

Write-Host "==== 最終出力 ===="
$text