class PpTable:AbstractTable {

    PpTable([object]$presen) {
        $this.GetTable($presen) | Out-Null
    }
    [pscustomobject] GetTable($presen) {
        $tables = $presen.slides | ForEach-Object { ($_.shapes | Where-Object { $null -ne $_.table } | ForEach-Object { $_.table }) }
        $data = @()
        $tables | ForEach-Object { 
            $_.rows | ForEach-Object {
                $r = @() 
                $_.Cells | ForEach-Object { $r += $_.Shape.TextFrame.TextRange.Text }
                $data += $null
                $data[$data.length - 1] = $r
            }
        }
        $this.header = $data[0]
        $this.data = @()
        $data | Where-Object { $_[0] -ne $data[0][0] } | ForEach-Object {
            $i = 0; $rc = [ordered]@{}
            foreach ($key in $this.header) {
                $rc.add($key, $_[$i])
                $i++
            }
            $this.data += [pscustomobject]$rc
        }
        return [pscustomobject]@{header = $this.header; data = $this.data }
    }
    [pscustomobject] toObject() {
        return [pscustomobject]@{header = $this.header; data = $this.data }
    }
}
