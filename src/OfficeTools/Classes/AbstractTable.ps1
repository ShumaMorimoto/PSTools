class AbstractTable {
    [string[]] $header = @()
    [pscustomobject[]] $data = @()

    [pscustomobject] toObject() {
        return [pscustomobject]@{header = $this.header; data = $this.data }
    }
    [object] toJSON() {
        return ConvertTo-JSON -depth 3 $this.toObject()
    }
    [object] Search([pscustomobject]$data, [ScriptBlock] $compfunc) {
        return $null
    }
    [void] Sort([ScriptBlock] $orderfunc) {
    }
    [object]AddRow([pscustomobject[]] $data) { 
        return $null
    }
    [object]SetHeader([string[]] $header) { 
        return $null
    }
}
