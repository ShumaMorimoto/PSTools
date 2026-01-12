using module D:\tool\Repository\PSTools\GPXTools

function Measure-TspPerformance {
    param(
        [double[,]]$Matrix,
        [int[][]]$ForbiddenPairs = @()   # 例: @( @(0,3), @(4,7) )
    )

    # --- 2. 禁止あり ---
    $matrix2 = $Matrix.Clone()

    foreach ($pair in $ForbiddenPairs) {
        $i = $pair[0]
        $j = $pair[1]
        $matrix2[$i,$j] = 100   # 禁止ルート設定
    }

    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    $route2 = [TspSolverLib.TspSolver]::SolveMatrix($matrix2)
    $sw2.Stop()

    $dist2 = Get-RouteDistance -Matrix $matrix2 -Route $route2


    # --- 結果 ---
    [PSCustomObject]@{
        Time_WithForbidden    = $sw2.ElapsedMilliseconds
        Distance_WithForbidden = [math]::Round($dist2, 3)
        Route_NoForbidden     = ($route1 -join " -> ")
        Route_WithForbidden   = ($route2 -join " -> ")
    }
}

function Get-ForbiddenByBottomK {
    param(
        [double[,]]$Matrix,
        [int]$K = 10
    )

    $rows = $Matrix.GetLength(0)
    $cols = $Matrix.GetLength(1)

    # ForbiddenPairs を格納する List[int[]]
    $list = [System.Collections.Generic.List[int[]]]::new()

    for ($i = 0; $i -lt $rows; $i++) {

        # 行の (距離, j) を全部集める（Infinity は除外）
        $pairs = @()
        for ($j = 0; $j -lt $cols; $j++) {
            $v = $Matrix[$i,$j]
            if ($v -ne [double]::PositiveInfinity) {
                $pairs += [PSCustomObject]@{ Dist = $v; J = $j }
            }
        }

        # 距離が小さい順にソート
        $sorted = $pairs | Sort-Object Dist

        # 上位 K 個だけ許可
        $allowed = $sorted[0..([math]::Min($K-1, $sorted.Count-1))].J

        # それ以外は全部禁止
        for ($j = 0; $j -lt $cols; $j++) {
            if ($allowed -notcontains $j) {
                $list.Add([int[]]@($i, $j))
            }
        }
    }

    return $list.ToArray()
}

function Get-ForbiddenByRowMinMax {
    param(
        [double[,]]$Matrix
    )

    $rows = $Matrix.GetLength(0)
    $cols = $Matrix.GetLength(1)

    # --- 行ごとの最小値を集める ---
    $rowMins = @()

    for ($i = 0; $i -lt $rows; $i++) {
        $minVal = [double]::PositiveInfinity

        for ($j = 0; $j -lt $cols; $j++) {
            $v = $Matrix[$i,$j]
            if ($v -lt $minVal) {
                $minVal = $v
            }
        }

        $rowMins += $minVal
    }

    # --- 行最小値の最大値（閾値） ---
    $threshold = ($rowMins | Measure-Object -Maximum).Maximum

    # --- ForbiddenPairs を作る（int[][]） ---
    $list = [System.Collections.Generic.List[int[]]]::new()

    for ($i = 0; $i -lt $rows; $i++) {
        for ($j = 0; $j -lt $cols; $j++) {

            $v = $Matrix[$i,$j]

            if ($v -eq [double]::PositiveInfinity) {
                continue
            }

            # ★ 閾値より大きいルートを禁止
            if ($v -gt $threshold) {
                $list.Add([int[]]@($i, $j))
            }
        }
    }

    return $list.ToArray()
}

function Get-ForbiddenByMedian {
    param(
        [double[,]]$Matrix
    )

    $rows = $Matrix.GetLength(0)
    $cols = $Matrix.GetLength(1)

    $forbidden = @()

    for ($i = 0; $i -lt $rows; $i++) {

        # 行の値を取得（Infinity は除外）
        $values = @()
        for ($j = 0; $j -lt $cols; $j++) {
            $v = $Matrix[$i,$j]
            if ($v -ne [double]::PositiveInfinity) {
                $values += $v
            }
        }

        if ($values.Count -eq 0) {
            continue
        }

        # --- 中央値を求める ---
        $sorted = $values | Sort-Object
        $count = $sorted.Count

        if ($count % 2 -eq 1) {
            $median = $sorted[ [int]($count / 2) ]
        }
        else {
            $median = ($sorted[$count/2 - 1] + $sorted[$count/2]) / 2
        }

        # --- 中央値より大きい (i→j) を Forbidden に追加 ---
        for ($j = 0; $j -lt $cols; $j++) {
            $v = $Matrix[$i,$j]

            if ($v -eq [double]::PositiveInfinity) {
                continue
            }

            if ($v -gt $median) {
                $forbidden += ,@($i, $j)
            }
        }
    }

    return ,$forbidden
}

function Get-RouteDistance {
    param(
        [double[,]]$Matrix,
        [int[]]$Route
    )

    $total = 0.0

    for ($i = 0; $i -lt $Route.Count - 1; $i++) {
        $from = $Route[$i]
        $to   = $Route[$i+1]
        $total += $Matrix[$from,$to]
    }

    return $total
}

# -----------------------------------------
# 初期マトリックスを作成して CSV に保存する関数
# -----------------------------------------
function Save-Matrix {
    param(
        [string]$Path = "matrix.csv"
    )

    $towns = [GPXService]::FromCityTowns("上越市")

    $Places = $towns.GetTrkpts()
    $places = $Places | ForEach-Object {
        [ValueTuple[double, double]]::new($_.lat, $_.lon)
    }
    # C# 側の距離行列生成
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $matrix = [TspSolverLib.TspSolver]::BuildMatrix($places)
    $sw.Stop()

    # CSV に保存
    $rows = for ($i = 0; $i -lt $matrix.getlength(0); $i++) {
        $line = for ($j = 0; $j -lt $matrix.getlength(1); $j++) {
            $matrix[$i, $j]
        }
        ($line -join ",")
    }

    $rows | Set-Content $Path
    Write-Output "Matrix saved to $Path"

    return ,$matrix
}


# -----------------------------------------
# 保存したマトリックスを読み込む関数
# -----------------------------------------
function Load-Matrix {
    param(
        [string]$Path = "matrix.csv"
    )

    $lines = Get-Content $Path
    $size = $lines.Count

    $matrix = New-Object 'double[,]' $size, $size

    $matrix = New-Object 'double[,]' $size, $size

    for ($i = 0; $i -lt $size; $i++) {
        $values = $lines[$i].Split(",")

        for ($j = 0; $j -lt $size; $j++) {

            $v = $values[$j]

            if ($v -eq "∞") {
                # ★ Infinity を正しく復元
                $matrix[$i, $j] = [double]::PositiveInfinity
            }
            else {
                $matrix[$i, $j] = [double]$v
            }
        }
    }
    return ,$matrix
}

function Test-MatrixConnectivity {
    param(
        [double[,]]$Matrix,
        [double]$Limit = 100
    )

    $rows = $Matrix.GetLength(0)
    $cols = $Matrix.GetLength(1)

    $isolatedRows = @()
    $isolatedCols = @()

    $rowMinValues = @()
    $colMinValues = @()

    # --- 行ごとのチェック ---
    for ($i = 0; $i -lt $rows; $i++) {

        $minVal = [double]::PositiveInfinity
        $reachable = $false

        for ($j = 0; $j -lt $cols; $j++) {
            $v = $Matrix[$i,$j]

            if ($v -lt $minVal) {
                $minVal = $v
            }

            if ($v -lt $Limit) {
                $reachable = $true
            }
        }

        $rowMinValues += $minVal

        if (-not $reachable) {
            $isolatedRows += $i
        }
    }

    # --- 列ごとのチェック ---
    for ($j = 0; $j -lt $cols; $j++) {

        $minVal = [double]::PositiveInfinity
        $reachable = $false

        for ($i = 0; $i -lt $rows; $i++) {
            $v = $Matrix[$i,$j]

            if ($v -lt $minVal) {
                $minVal = $v
            }

            if ($v -lt $Limit) {
                $reachable = $true
            }
        }

        $colMinValues += $minVal

        if (-not $reachable) {
            $isolatedCols += $j
        }
    }

    # --- 最小値の最大値 ---
    $maxOfRowMin = ($rowMinValues | Measure-Object -Maximum).Maximum
    $maxOfColMin = ($colMinValues | Measure-Object -Maximum).Maximum

    # 結果を返す
    [PSCustomObject]@{
        Limit              = $Limit
        IsolatedRows       = $isolatedRows
        IsolatedCols       = $isolatedCols
        MaxRowMinDistance  = $maxOfRowMin
        MaxColMinDistance  = $maxOfColMin
    }
}
