function ConvertTo-KeyedHashTable {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [array]$data,

        [Parameter(Position = 1)]
        [string]$key
    )
    if (-not $data -or $data.Count -eq 0) {
        throw "データ配列が空です"
    }
    # キーが未指定なら、最初のハッシュテーブルの先頭キーを使う
    if (-not $key) {
        $firstItem = $data[0]
        $key = ($firstItem.Keys | Select-Object -First 1)
    }
    $result = [ordered]@{}
    foreach ($item in $data) {
        if ($item.Keys -contains $key) {
            # 内側のハッシュを順序付きに変換
            $orderedItem = [ordered]@{}
            foreach ($k in $item.Keys) {
                $orderedItem[$k] = $item[$k]
            }
            $result[$item[$key]] = $orderedItem
        }
    }
    return $result
}
