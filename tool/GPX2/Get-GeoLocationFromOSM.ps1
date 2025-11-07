<#
.SYNOPSIS
    世界中の地名キーワードから緯度と経度を取得します。

.DESCRIPTION
    OpenStreetMap(Nominatim)のAPIを利用して、指定された地名の緯度と経度を検索します。
    結果はコンソールに表示されます。
    -CopyToClipboard スイッチを指定すると、結果を「緯度,経度」の形式でクリップボードにコピーします。

.PARAMETER Keyword
    緯度経度を検索したい地名キーワード。
    パイプラインからの入力も受け付けます。

.PARAMETER CopyToClipboard
    このスイッチを指定すると、取得した緯度経度をクリップボードにコピーします。

.EXAMPLE
    PS C:\> Get-GeoLocationFromOSM -Keyword "Eiffel Tower"

    Keyword      DisplayName                                                                       Latitude Longitude
    -------      -----------                                                                       -------- ---------
    Eiffel Tower Tour Eiffel, 5, Avenue Anatole France, Quartier du Gros-Caillou, 7e Arrondiss... 48.85837  2.29448

.EXAMPLE
    PS C:\> Get-GeoLocationFromOSM -Keyword "Statue of Liberty" -CopyToClipboard

    クリップボードにコピーしました: 40.68925,-74.0445
    Keyword             DisplayName                                                              Latitude Longitude
    -------             -----------                                                              -------- ---------
    Statue of Liberty   Statue of Liberty, Liberty Island, Manhattan, New York, 10004, United States 40.68925 -74.0445

    (この後、クリップボードに "40.68925,-74.0445" がコピーされます)

.NOTES
    - OpenStreetMapの利用規約に従い、過度なアクセスは避けてください。
    - APIのポリシーに従い、カスタムのUser-Agentを設定しています。
#>
function Get-GeoLocationFromOSM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Keyword,

        [Parameter()]
        [switch]$CopyToClipboard
    )

    begin {
        try {
            Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
        }
        catch {}
    }

    process {
        try {
            $encodedKeyword = [System.Web.HttpUtility]::UrlEncode($Keyword)
            
            # APIの利用ポリシーに従い、カスタムのUser-Agentを設定することが推奨されています
            $headers = @{
                "User-Agent" = "PowerShell-Geocoding-Script"
            }

            # OpenStreetMap Nominatim APIのエンドポイント
            $uri = "https://nominatim.openstreetmap.org/search?q=$encodedKeyword&format=json"

            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop

            if ($null -ne $response -and $response.Count -gt 0) {
                # 最初の結果を取得
                $firstResult = $response[0]

                # 緯度と経度を変数に格納
                $latitude  = [double]$firstResult.lat
                $longitude = [double]$firstResult.lon

                # (新機能) -CopyToClipboard スイッチが指定されていたらクリップボードにコピー
                if ($CopyToClipboard.IsPresent) {
                    $clipboardText = "$latitude,$longitude"
                    Set-Clipboard -Value $clipboardText
                    # ユーザーにコピーしたことを通知
                    Write-Host "クリップボードにコピーしました: $clipboardText" -ForegroundColor Green
                }

                # (従来機能) 結果をカスタムオブジェクトとして標準出力
                [PSCustomObject]@{
                    Keyword     = $Keyword
                    DisplayName = $firstResult.display_name
                    Latitude    = $latitude
                    Longitude   = $longitude
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
