$codetbl = @{'2004022702' = '148106'; '2017022703' = '252653'; '201707310A' = '252845'; '2016012906' = '261385' }

$codes = @('2004022702', '2017022703', '201707310A', '2016012906')

$method = "GET"
$contentType = "application/json; charset=utf-8"
$url = "https://developer.am.mufg.jp/fund_information_latest/fund_cd/"
$url2 = "https://script.google.com/macros/s/AKfycbwEPwDg8kAuRPb6ekNASA25HFNowUcMxngLwgMjNrQFlXVkal_PiZrItVxmMQMniSg4/exec"


foreach ($code in $codes) {
    $url3 = $url + $codetbl[$code]

    $response = Invoke-RestMethod -Uri $url3 -Method $method -ContentType $contentType

    $fund_code = $response.datasets[0].fund_cd
    $base_date = $response.datasets[0].base_date
    $nav = $response.datasets[0].nav
    $cmp_prev_day = $response.datasets[0].cmp_prev_day

    $url3 = $url2
    $url3 += "?code=" + $code
    $url3 += "&date=" + $base_date
    $url3 += "&nav=" + $nav
    $url3 += "&cmp=" + $cmp_prev_day

    Invoke-RestMethod -Uri $url3 -Method $method -ContentType $contentType
}

