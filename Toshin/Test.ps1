# モジュールを読み込み（パスは環境に合わせて調整してください）
using module "D:\tool\Repository\PSTools\開発中\newToshin\Toshin\Toshin.psm1"

$codes = @(
    "2000032406", "2004022702", "1998040104", "2011083106",
    "2023031301", "2005022803", "2013121001", "2017022703",
    "2025120101", "2011110102", "201707310A", "2016012906",
    "2001112212", "2004073003", "201707310D", "2012052801"
)

Write-Host "=== ToshinDAO 銘柄一括テスト開始 ===" -ForegroundColor Cyan
Write-Host "対象数: $($codes.Count) 件`n"

$dao = [ToshinDAO]::new()
$results = @()

try {
    foreach ($code in $codes) {
        Write-Host "取得中: $code ... " -NoNewline
        
        $elapsed = Measure-Command {
            try {
                $price = $dao.GetPrice($code)
                $results += $price
                
                if ($null -ne $price.date) {
                    Write-Host "成功 [Date: $($price.date), Price: $($price.nav)]" -ForegroundColor Green
                } else {
                    Write-Host "失敗 (データ取得不可)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "エラー ($($_.Exception.Message))" -ForegroundColor Red
            }
        }
    }
}
finally {
    # ブラウザプロセスを確実に終了
    $dao.Dispose()
    Write-Host "`nブラウザセッションを終了しました。" -ForegroundColor Gray
}

# 最終結果をテーブル表示
Write-Host "`n=== 最終実行結果 ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# 統計
$successCount = ($results | Where-Object { $null -ne $_.date }).Count
Write-Host "統計: 全 $($codes.Count) 件中 $successCount 件 成功" -ForegroundColor ($successCount -eq $codes.Count ? "Green" : "Yellow")