toA1([hashtable]$range) {
        if ($range.Row -lt 1 -or $range.Column -lt 1) {
            throw "Row and Column must be >= 1"
        }
        # 列番号 → アルファベット（例：2 → "B", 27 → "AA"）
        $colLetters = ""
        $col = $range.Column
        while ($col -gt 0) {
            $col--
            $char = [char]($col % 26 + [int][char]'A')
            $colLetters = "$char$colLetters"
            $col = [math]::Floor($col / 26)
        }
        return [string]($colLetters + [string]($range.Row))
    }
