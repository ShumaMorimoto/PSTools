# GAFunctions.psm1
function Test-GA {
    param($x)
    return "Test-GA called with $x"
}
Export-ModuleMember -Function Test-GA
