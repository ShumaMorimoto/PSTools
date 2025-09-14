class OTExcelDAO {
    static [object] $excel
    [object] $book
    [hashtable] $tables = @{}

    [void]Show() {
        if (-not [OTExcelDAO]::excel.Visible) {
            [OTExcelDAO]::excel.Visible = $true
            if ($this.book.ReadOnly) { $this.book.ChangeFileAccess(2) }
        } 
    }
    [void]Save() {
        $this.book.Save()
    }
    [void]Close() {
        $this.book.Close()
    }
    OTExcelDAO([string]$path, [boolean]$readOnly = $true) {
        $this.initialize($path, $readOnly)
    }
    [void] initialize([string]$path, [boolean]$readOnly) {
        $path -match "[^\\]+\.xls[m]*"
        $bookname = $Matches[0]
        try {
            if ($null -ne [OTExcelDAO]::excel) {
                $this.book = [OTExcelDAO]::excel.Workbooks | Where-Object Name -eq $bookname
                if ($null -eq $this.book ) {
                    $this.book = [OTExcelDAO]::excel.Workbooks.Open($path, 0, $readOnly)
                }
            }
            else {
                throw "New Object"
            }
        }
        catch {
            Get-Process | where-object name -eq "Excel" | Stop-Process
            [OTExcelDAO]::excel = New-Object -ComObject Excel.Application
            $this.book = [OTExcelDAO]::excel.Workbooks.Open($path, 0, $readOnly)  
        }
    }
    [Extable] GetTable([object]$parm, [string]$header) {
        $sheet = $this.book.Worksheets($parm)
        $range = $sheet.Range($header)
        $table = New-Object ExTable($range)
        $this.tables.Add($sheet.Name, $table)
        return $table
    }
}
