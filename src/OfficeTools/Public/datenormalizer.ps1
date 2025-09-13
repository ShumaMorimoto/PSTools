function datenormalizer {
    param([string]$val1, [string]$val2)
    
    switch -Regex ($val1) {       
        '(2\d/\d+/\d+)' {
            $order = [DateTime]::ParseExact($Matches[1], "yy/M/d", $null).toString("yyMMdd")
            if ($val2 -match "(\d+):(\d+)") {
                $order += $Matches[1].PadLeft(2, "0") + $Matches[2].PadLeft(2, "0")
            }
            else {
                $order += "9999"
            }
            break
        }
        '(2\d/\d+)/*([上中下末])' {
            $date = [DateTime]::ParseExact($Matches[1], "yy/M", $null)
            switch ($Matches[2]) {
                "上" { $order = $date.ToString("yyMM") + "109999" }
                "中" { $order = $date.ToString("yyMM") + "209999" }
                "下" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
                "末" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
            }
            break
        }
        '(\d+)月' {
            $order = (Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1].PadLeft(2, "0") + "019999"
            break
        }
        '(\d+)/*([上中下末])' {
            $date = [DateTime]::ParseExact((Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1], "yyM", $null)
            switch ($Matches[2]) {
                "上" { $order = $date.ToString("yyMM") + "109999" }
                "中" { $order = $date.ToString("yyMM") + "209999" }
                "下" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
                "末" { $order = $date.AddMonths(1).ToString("yyMMdd0000") }
            }
            break
        }
        '(2\d/\d+)' {
            $order = [DateTime]::ParseExact($Matches[1], "yy/M", $null).ToString("yyMM019999")
            break
        }
        '(\d+)/(\d+)[週-]*' {
            $order = (Get-Date).AddYears(1).AddMonths(-$Matches[1]).toString("yy") + $Matches[1].PadLeft(2, "0") + $Matches[2].Padleft(2, "0") 
            if ($val2 -match "(\d+):(\d+)") {
                $order += $Matches[1].PadLeft(2, "0") + $Matches[2].PadLeft(2, "0")
            }
            else {
                $order += "9999"
            }
            break
        }
        default { $order = "9999999999" }
    }
    return [string]$order
}
