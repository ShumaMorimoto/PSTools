function Split-Simple {
    param([array]$items, [int]$maxSize = 3)

    # グループは「配列」ではなく「オブジェクトの Items プロパティ」に入れて返す
    if ($items.Count -le $maxSize) {
        return @(
            [pscustomobject]@{
                Items = [object[]]$items
            }
        )
    }

    $mid   = [math]::Floor($items.Count / 2)
    $left  = $items[0..($mid-1)]
    $right = $items[$mid..($items.Count-1)]

    $result = @()
    foreach ($subset in @($left, $right)) {
        $childGroups = Split-Simple -items $subset -maxSize $maxSize
        # ここは“そのまま配列結合”。enumerationされても中身はオブジェクトなので壊れない
        $result += $childGroups
    }
    return $result
}

# --- テスト ---
$data = 1..10
$groups = Split-Simple $data -maxSize 3

Write-Host "Total groups: $($groups.Count)"
foreach ($g in $groups) {
    Write-Host ("Group size={0} values={1}" -f $g.Items.Count, ($g.Items -join ','))
}

