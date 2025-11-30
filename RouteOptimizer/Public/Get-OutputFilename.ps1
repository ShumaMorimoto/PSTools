function Get-OutputFileName {
    param(
        [string]$InputFile,
        [string]$Suffix = "processed"
    )

    # 相対パスを絶対パスにリゾルブ
    $resolvedPath = (Resolve-Path $InputFile).Path

    $dir      = [System.IO.Path]::GetDirectoryName($resolvedPath)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
    $ext      = [System.IO.Path]::GetExtension($resolvedPath)

    # パターン: name_suffix または name_suffix_NN
    $pattern = "^(?<name>.+?)_(?<suffix>$Suffix)(_(?<num>\d+))?$"
    $match   = [regex]::Match($baseName, $pattern)

    if ($match.Success) {
        # 既に suffix が付いている場合
        $name   = $match.Groups["name"].Value
        $suffix = $match.Groups["suffix"].Value
        $num    = $match.Groups["num"].Value

        if ($num) {
            $counter = [int]$num + 1
        } else {
            $counter = 1
        }
        $newName = "{0}_{1}_{2:D2}{3}" -f $name, $suffix, $counter, $ext
    } else {
        # suffix 未付与の場合
        $newName = "${baseName}_${Suffix}$ext"
    }

    $fullPath = Join-Path $dir $newName

    # 衝突回避ループ（ゼロパディング）
    $counter = if ($match.Success -and $match.Groups["num"].Success) { [int]$match.Groups["num"].Value + 1 } else { 1 }
    while (Test-Path $fullPath) {
        $newName = "{0}_{1}_{2:D2}{3}" -f $baseName, $Suffix, $counter, $ext
        $fullPath = Join-Path $dir $newName
        $counter++
    }

    return $fullPath
}