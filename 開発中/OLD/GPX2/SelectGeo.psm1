# PowerShell Module for Geocoding
# FileName: GeoLocation.psm1
#
# Contains two functions:
# 1. Get-GeoLocation: Core function to fetch location data from APIs.
# 2. Select-GeoLocationToClipboard: UI function to select a location and copy coordinates.

#region Core Function: データ取得を担当
<#
.SYNOPSIS
    地名キーワードから緯度経度の候補リストを取得します。

.DESCRIPTION
    指定された地名キーワードを使い、国土地理院(GSI)またはOpenStreetMap(OSM)のAPIから
    緯度経度の候補をすべて検索します。結果は整形されたオブジェクトの配列として返されます。
    この関数は純粋なデータ取得のみを行い、UI操作やクリップボード操作は含みません。

.PARAMETER Keyword
    緯度経度を検索したい地名キーワード。
    パイプラインからの入力も受け付けます。

.PARAMETER Source
    検索に使用するAPIソースを指定します。
    - GSI: 国土地理院 (日本の地名に強い・デフォルト)
    - OSM: OpenStreetMap (全世界の地名に対応)

.EXAMPLE
    PS C:\> Get-GeoLocation -Keyword "東京"

    DisplayName        Latitude Longitude SourceAPI
    -----------        -------- --------- ---------
    東京都             35.6895      139.6917    GSI
    東京               35.6895      139.6917    GSI
    東京都千代田区     35.694       139.754     GSI
    東京駅             35.68124     139.76712   GSI
    ...

.EXAMPLE
    PS C:\> Get-GeoLocation -Keyword "Paris" -Source OSM

    DisplayName                                                               Latitude Longitude SourceAPI
    -----------                                                               -------- --------- ---------
    Paris, Île-de-France, France                                              48.85717  2.3414     OSM
    Paris, Lamar County, Texas, 75460, United States                          33.66094  -95.55551  OSM
    ...

.OUTPUTS
    PSCustomObjectの配列。各オブジェクトは DisplayName, Latitude, Longitude, SourceAPI のプロパティを持ちます。
#>
function Get-GeoLocation {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Keyword,

        [Parameter()]
        [ValidateSet("GSI", "OSM")]
        [string]$Source = "GSI"
    )

    begin {
        try {
            Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
        } catch {}
    }

    process {
        try {
            $encodedKeyword = [System.Web.HttpUtility]::UrlEncode($Keyword)
            $results = @()
            
            switch ($Source) {
                "GSI" {
                    $uri = "https://msearch.gsi.go.jp/address-search/AddressSearch?q=$encodedKeyword"
                    $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
                    if ($null -ne $response) {
                        # GSIの応答は単一オブジェクトか配列かの揺れがあるので、配列に統一する
                        $responseArray = if ($response -is [array]) { $response } else { @($response) }
                        
                        foreach ($item in $responseArray) {
                            $results += [PSCustomObject]@{
                                DisplayName = $item.properties.title
                                Latitude    = $item.geometry.coordinates[1]
                                Longitude   = $item.geometry.coordinates[0]
                                SourceAPI   = "GSI"
                            }
                        }
                    }
                }
                "OSM" {
                    $uri = "https://nominatim.openstreetmap.org/search?q=$encodedKeyword&format=json&limit=20" # 候補数を増やすためにlimitを指定
                    $headers = @{ "User-Agent" = "PowerShell-Geocoding-Script/2.0" }
                    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
                    if ($null -ne $response) {
                        # OSMの応答は単一オブジェクトか配列かの揺れがあるので、配列に統一する
                        $responseArray = if ($response -is [array]) { $response } else { @($response) }
                        
                        foreach ($item in $responseArray) {
                            $results += [PSCustomObject]@{
                                DisplayName = $item.display_name
                                Latitude    = [double]$item.lat
                                Longitude   = [double]$item.lon
                                SourceAPI   = "OSM"
                            }
                        }
                    }
                }
            }
            
            # 結果をパイプラインに流す
            return $results

        } catch {
            Write-Error "キーワード '$Keyword' の処理中にエラーが発生しました: $($_.Exception.Message)"
        }
    }
}
#endregion

#region UI Function: ユーザー操作とクリップボードコピーを担当
<#
.SYNOPSIS
    地名を検索し、対話的に選択して緯度経度をクリップボードにコピーします。

.DESCRIPTION
    内部で Get-GeoLocation 関数を呼び出して地名の候補を取得します。
    - 候補が複数ある場合: グリッドビューを表示してユーザーに選択を促します。
    - 候補が1つの場合: 自動でそれを選択します。
    - 候補がない場合: 警告メッセージを表示します。
    選択された拠点の緯度経度を "緯度,経度" の形式でクリップボードにコピーします。

.PARAMETER Keyword
    検索したい地名キーワード。

.PARAMETER Source
    検索に使用するAPIソースを指定します。 (GSI or OSM)

.EXAMPLE
    PS C:\> Select-GeoLocationToClipboard -Keyword "札幌"
    (グリッドビューが表示され、選択した拠点の緯度経度がクリップボードにコピーされる)

.EXAMPLE
    PS C:\> Select-GeoLocationToClipboard -Keyword "Big Ben" -Source OSM
    (海外の地名なのでOSMを指定。結果が1件なら自動でコピー、複数ならグリッドビューが表示される)

.NOTES
    この関数は Out-GridView コマンドレットを使用します。
    Windows PowerShell 5.1 または PowerShell 7 以降が必要です。
#>
function Select-GeoLocationToClipboard {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Keyword,

        [Parameter()]
        [ValidateSet("GSI", "OSM")]
        [string]$Source = "GSI"
    )

    try {
        Write-Verbose "地名 '$Keyword' をソース '$Source' で検索します..."
        $locations = Get-GeoLocation -Keyword $Keyword -Source $Source -ErrorAction SilentlyContinue

        if ($null -eq $locations -or $locations.Count -eq 0) {
            Write-Warning "キーワード '$Keyword' に一致する場所が見つかりませんでした。"
            return
        }

        $selectedLocation = $null
        if ($locations.Count -eq 1) {
            $selectedLocation = $locations[0]
            Write-Host "候補が1件見つかりました。自動的に選択します。" -ForegroundColor Cyan
        }
        else {
            Write-Host "複数の候補が見つかりました。グリッドビューから1つ選択してください。" -ForegroundColor Cyan
            $selectedLocation = $locations | Out-GridView -Title "場所を選択してください: $Keyword" -PassThru
        }

        if ($null -eq $selectedLocation) {
            Write-Warning "場所が選択されなかったか、キャンセルされました。"
            return
        }

        # ShouldProcessの確認
        if ($PSCmdlet.ShouldProcess(
            "'$($selectedLocation.DisplayName)'", 
            "緯度経度 ($($selectedLocation.Latitude),$($selectedLocation.Longitude)) をクリップボードにコピー")
        ) {
            $clipboardText = "$($selectedLocation.Latitude),$($selectedLocation.Longitude)"
            Set-Clipboard -Value $clipboardText

            Write-Host "以下の情報をクリップボードにコピーしました。" -ForegroundColor Green
            Write-Host "  地名 : $($selectedLocation.DisplayName)"
            Write-Host "  緯度,経度 : $clipboardText"
        }

    } catch {
        Write-Error "処理中にエラーが発生しました: $($_.Exception.Message)"
    }
}
#endregion

# モジュールとしてインポートされたときに関数をエクスポートする
Export-ModuleMember -Function Get-GeoLocation, Select-GeoLocationToClipboard
