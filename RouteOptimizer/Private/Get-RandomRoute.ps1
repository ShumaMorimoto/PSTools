function Get-RandomRoute($places) {
    return $places | Sort-Object { Get-Random }
}
