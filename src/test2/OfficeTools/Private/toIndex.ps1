toIndex([string]$a1) {
        # 正規表現で列と行を分離（例："B4" → "B", "4"）
        if ($a1 -match '^([A-Z]+)(\d+)$') {
            $colLetters = $matches[1]
            $rowNumber = [int]$matches[2]
            # 列文字 → 数値変換（例："B" → 2, "AA" → 27）
            $colNumber = 0
            foreach ($char in $colLetters.ToCharArray()) {
                $colNumber = $colNumber * 26 + ([int][char]$char - [int][char]'A' + 1)
            }

            return [ordered]@{Row = $rowNumber; Column = $colNumber }
        }
        else {
            throw "Invalid A1 format: $a1"
        }
    }
