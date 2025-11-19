function Select-Parent($population, $tournamentSize = 5) {
    $candidates = @()
    for ($i = 0; $i -lt $tournamentSize; $i++) {
        $candidates += ,$population[(Get-Random -Minimum 0 -Maximum $population.Count)]
    }
    return ($candidates | Sort-Object { Get-TotalDistance $_ })[0]
}
