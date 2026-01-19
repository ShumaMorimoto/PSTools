using module Toshin
using module OfficeTools

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
    $gs = [OTGSheetDAO]::new($spreadsheetId)

    # --- 1. 銘柄リストの動的取得 ---
    # C1（見出し）からG列のデータ終端まで取得
    $fullRange = "シート1!C1:G" 
    $tbl = $gs.GetTable("銘柄", $fullRange) 
    
    # 見出しを除いたデータ行数が現在の銘柄数
    $rowCount = $tbl.oRows.Count
    Write-Log "現在検知された銘柄数: $($rowCount)件"

    # --- 2. 基準日・時価エリアの動的特定 ---
    # 銘柄数 + 2 行目にある想定（例：16銘柄なら 18行目）
    $targetStartRow = $rowCount + 2
    
    # 基準日範囲の作成 (例: "シート1!I18:I19")
    $bdayRange = "シート1!I$($targetStartRow):I$($targetStartRow + 1)"
    $bday = $gs.GetTable("基準日", $bdayRange)
    
    # 時価・履歴挿入範囲の作成 (例: "シート1!I18:M20")
    $jikaRange = "シート1!I$($targetStartRow):M$($targetStartRow + 2)"

    $base = (Get-Date).AddHours(6).AddWorkDays(-1).Date.ToString("M月d日")

    # --- 3. 基準日チェックと履歴挿入 ---
    if ($bday.oRows[0].日付 -ne $base) {
        Write-Log "新営業日 ($base) を検知。$($targetStartRow)行目に履歴を挿入します。"
        
        # 動的に算出した範囲で履歴テーブルを取得して挿入
        $jika = $gs.GetTable("時価", $jikaRange)
        $jika.InsertRow(0)
        $sum = $jika.oRows[0]
        $sum._row ++
        $jika.UpdateRow($sum)

        # 基準日のセル自体を更新
        $bday.oRows[0].日付 = $base
        $bday.UpdateRow($bday.oRows[0])
    }

    # --- 4. スクレイピング処理 ---
    $unupdated = $tbl.oRows | Where-Object { $_.日付 -ne $base }

    if ($unupdated.Count -gt 0) {
        Write-Log "★★★ START: 投信更新（残り $($unupdated.Count) 件） ★★★"
        $toshin = [ToshinDAO]::new($false)
        try {
            foreach ($row in $unupdated) {
                $elapsed = Measure-Command {
                    try {
                        $price = $toshin.GetPrice($row.コード)
                        if ($null -ne $price.date) {
                            $row.更新日時 = (Get-Date).ToString("M月d日 HH:mm")
                            $row.日付 = ([datetime]::ParseExact($price.date, "yyyyMMdd", $null)).ToString("M月d日")
                            $row.価格 = $price.nav
                            $row.前日比 = $price.cmp
                            
                            # ここで更新。銘柄が増えても $row.コード 等の内部インデックスは維持される
                            $tbl.UpdateRow($row)
                            Write-Log ("[{0}] {1} {2} ({3} sec)" -f $price.code, $price.date, $price.nav, $elapsed.TotalSeconds.ToString("F2"))
                        }
                    }
                    catch {
                        Write-Log "【ERROR】コード:$($row.コード) 理由:$($_.Exception.Message)" "ERROR"
                    }
                }
            }
        }
        finally {
            $toshin.Dispose()
        }
    }

    # --- 5. 完了判定と通知 ---
    $tbl.Load() | Out-Null
    $remaining = $tbl.oRows | Where-Object { $_.日付 -ne $base }

    if ($remaining.Count -eq 0) {
        # SendJika 内でも同様の動的計算が必要なため修正
        SendJikaDynamic -spreadsheetId $spreadsheetId -rowCount $rowCount
        Write-Log "★★★ END: 全銘柄完了 ★★★"
    }
    else {
        Write-EventLog -LogName Application -Source "投信更新" `
            -EventId 1001 -EntryType Information `
            -Message ("残銘柄(" + $codes.count + ")")
        Write-log "★★★　END（投信更新:残$($codes.count)）　★★★"

        Write-Log "★★★ END: 未完了あり（残: $($remaining.Count)） ★★★"
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

function SendJikaDynamic($spreadsheetId, $rowCount) {
    $gs = [OTGSheetDAO]::new($spreadsheetId)
    
    # 銘柄リストと、その直下の時価合計を取得
    $targetStartRow = $rowCount + 2
    $tbl = $gs.GetTable("銘柄別時価", "シート1!B1:G$($rowCount + 1)")
    $sum = $gs.GetTable("総計時価", "シート1!I$($targetStartRow ):M$($targetStartRow + 1)")

    $summaryRow = $sum.oRows[0]
    $subject = "【投信:$($summaryRow.前日比)円】＠$((Get-Date).ToString("HH:mm"))"

    $message = @("時価:$($summaryRow.時価)円 損益:$($summaryRow.損益)円 ($($summaryRow.前日比)円)", "")
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
