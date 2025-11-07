<#
.SYNOPSIS
    日本の地名キーワードから緯度と経度を取得します。

.DESCRIPTION
    国土地理院の地理院地図APIを利用して、指定された地名の緯度と経度を検索します。
    結果はコンソールに表示されます。
    -CopyToClipboard スイッチを指定すると、結果を「緯度,経度」の形式でクリップボードにコピーします。

.PARAMETER Keyword
    緯度経度を検索したい地名キーワード。
    パイプラインからの入力も受け付けます。

.PARAMETER CopyToClipboard
    このスイッチを指定すると、取得した緯度経度をクリップボードにコピーします。

.EXAMPLE
    PS C:\> Get-GeoLocation -Keyword "東京駅"

    Keyword   Address        Latitude  Longitude
    -------   -------        --------  ---------
    東京駅    東京都千代田区   35.68124  139.76712

.EXAMPLE
    PS C:\> Get-GeoLocation -Keyword "スカイツリー" -CopyToClipboard

    Keyword      Address              Latitude  Longitude
    -------      -------              --------  ---------
    スカイツリー 東京都墨田区押上１丁目 35.71006  139.8107

    (この後、クリップボードに "35.71006,139.8107" がコピーされます)

.EXAMPLE
    PS C:\> "函館山", "五稜郭" | Get-GeoLocation -CopyToClipboard

    (パイプラインで複数処理した場合、最後の結果である「五稜郭」の緯度経度がクリップボードに残ります)
#>
function Get-GeoLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Keyword,

        [Parameter()]
        [switch]$CopyToClipboard
    )

    begin {
        # .NETアセンブリを読み込み、URLエンコード機能を利用可能にする
        try {
            Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
        }
        catch {}
    }

    process {
        try {
            # キーワードをURLエンコードする
            $encodedKeyword = [System.Web.HttpUtility]::UrlEncode($Keyword)

            # 国土地理院APIのエンドポイントURLを構築
            $uri = "https://msearch.gsi.go.jp/address-search/AddressSearch?q=$encodedKeyword"

            # APIを呼び出して結果を取得
            $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop

            # 検索結果があるか確認
            if ($null -ne $response -and $response.Count -gt 0) {
                # 最初の結果を取得
                $firstResult = $response[0]

                # 緯度と経度を変数に格納
                $latitude  = $firstResult.geometry.coordinates[1]
                $longitude = $firstResult.geometry.coordinates[0]

                # (新機能) -CopyToClipboard スイッチが指定されていたらクリップボードにコピー
                if ($CopyToClipboard.IsPresent) {
                    $clipboardText = "$latitude,$longitude"
                    Set-Clipboard -Value $clipboardText
                    # ユーザーにコピーしたことを通知
                    Write-Host "クリップボードにコピーしました: $clipboardText" -ForegroundColor Green
                }

                # (従来機能) 結果をカスタムオブジェクトとして標準出力
                [PSCustomObject]@{
                    Keyword   = $Keyword
                    Address   = $firstResult.properties.title
                    Latitude  = $latitude
                    Longitude = $longitude
                }
            }
            else {
                Write-Warning "キーワード '$Keyword' に一致する結果が見つかりませんでした。"
            }
        }
        catch {
            Write-Error "キーワード '$Keyword' の処理中にエラーが発生しました: $($_.Exception.Message)"
        }
    }
}
