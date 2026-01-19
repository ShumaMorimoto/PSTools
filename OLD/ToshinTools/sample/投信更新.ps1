using module OfficeTools
using module ToshinTools

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    Write-Output "[$timestamp] [$Level] $Message"
}

function UpdateJika() {
    $spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU"
    $range = "シート1!C1:G18"
    $base = (Get-Date).AddHours(6).AddWorkDays(-1).Date

    $gs = [OTGSheetDAO]::new($spreadsheetId)
    $tbl = $gs.GetTable("銘柄", $range)
    $codes = $tbl.oRows | Where-Object { [datetime]::ParseExact($_.日付, "M月d日", $null) -lt $base } 

    try {
        $prices = @()
        if ($codes.count -eq 0) {
            Write-log "★★★　SKIPED（投信更新）　★★★"
        }
        else {
            Write-log "★★★　START（投信更新）　★★★"

            foreach ($code in $codes) {
                try {
                    $price = $null
                    $elapsed = Measure-Command {
                        $price = [ToshinDAO]::GetPrice($code.コード)
                    }
                    if ($null -ne $price.date ) {
                        Write-log "コード:$($price.code) 基準日:$($price.date) 基準価額:$($price.nav) 前日比:$($price.cmp) 処理時間（$($elapsed.TotalSeconds) sec）"

                        $code.更新日時 = (Get-Date).ToString("M月d日 HH:mm")
                        $code.日付 = ([datetime]::ParseExact($price.date, "yyyyMMdd", $null)).ToString("M月d日")
                        $code.価格 = $price.nav
                        $code.前日比 = $price.cmp

                        $tbl.UpdateRow($code)

                        $prices += $price
                    }
                    else {
                        Write-log "【ERROR】コード:$($price.code) 処理時間（$($elapsed.TotalSeconds) sec）"               
                    }
                }
                catch {
                    Write-log "【ERROR】コード:$($price.code) 処理時間（$($elapsed.TotalSeconds) sec）"
                }
            }
        }
        $tbl.Load() | Out-Null
        $codes = $tbl.oRows | Where-Object { [datetime]::ParseExact($_.日付, "M月d日", $null) -lt $base } 
      
        if ($codes.count -gt 0) {
            Write-EventLog -LogName Application -Source "投信更新" `
                -EventId 1001 -EntryType Information `
                -Message ("残銘柄(" + $codes.count + ")")
            Write-log "★★★　END（投信更新:残$($codes.count)）　★★★"
        }
        else {
            SendJika  | Out-Null
            Write-log "★★★　END（メール送信完了）　★★★"
        }
    }
    catch {
        Write-Log "★★★　ERROR　★★★"   
    }
}
function Get-DisplayWidth {
    param ($str)
    $width = 0
    foreach ($char in $str.ToCharArray()) {
        if ([System.Text.Encoding]::GetEncoding("Shift_JIS").GetByteCount($char) -gt 1) {
            $width += 2  # 全角
        }
        else {
            $width += 1  # 半角
        }
    }
    return $width
}
function PadRightDisplay {
    param (
        [string]$str,
        [int]$targetWidth
    )
    $currentWidth = Get-DisplayWidth $str
    $padding = $targetWidth - $currentWidth
    return $str + (" " * $padding)
}
function ConvertTo-Base64Url {
    param ($input)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($input)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $base64.Replace('+', '-').Replace('/', '_').Replace('=', '')
}
function SendJika() {
    $spreadsheetId = "1Ghl91D5pPAL3pmU1Ywh3tv6IC0b6D43QgoIq6cagHSU"
    $range = "シート1!B1:L16"
    $rangeall = "シート1!I17:L18"

    $gs = [OTGSheetDAO]::new($spreadsheetId)

    $tbl = $gs.GetTable("銘柄別時価", $range)
    $sum = $gs.GetTable("総計時価", $rangeall)

    $subject = "【投信:$($sum.oRows.前日比)円】＠$((Get-Date).ToString("HH:mm"))"

    $message = @("時価:$($sum.oRows.時価)円 損益:$($sum.oRows.損益)円 ($($sum.oRows.前日比)円)")
    foreach ($row in $tbl.oRows) {
        $message += "$(PadRightDisplay $row.略称 12)  $($row.日付) {0,7} ({1,5}): {2,10}" -f $row.価格, $row.前日比, $row.前日比損益
    }

    Send-Message "shumamorimoto@gmail.com" $subject ($message -join "`r`n")
}


# ログファイル名にタイムスタンプとプロセスIDを付加
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "D:\tool\log\transcript_$timestamp`_PID$pid.txt" 

Start-Transcript -Path $logFile | Out-NUll

UpdateJika

Stop-Transcript | Out-NUll

