function Group-Places {
    param (
        [Parameter(Mandatory)] [array]$Towns,
        [double]$MaxDistanceKm = 1.0,
        [int]$MaxGroupSize = 20
    )

    $unassigned = $Towns.Clone()
    $grouped = @()
    $groupIndex = 1

    while ($unassigned.Count -gt 0) {
        $seed = $unassigned[0]
        $group = @($seed)
        $unassigned = $unassigned | Where-Object { $_ -ne $seed }

        # 距離を計算して近い順にソート
        $sortedCandidates = $unassigned | Sort-Object {
            Get-Distance $seed $_
        }

        foreach ($candidate in $sortedCandidates) {
            if ($group.Count -ge $MaxGroupSize) { break }

            $dist = Get-Distance $seed $candidate
            if ($dist -le $MaxDistanceKm) {
                $group += $candidate
            }
        }

        Write-Host "Group $groupIndex size: $($group.Count)"
        $grouped += ,$group
        $unassigned = $unassigned | Where-Object { $group -notcontains $_ }
        $groupIndex++
    }

    Write-Host "Total groups formed: $($grouped.Count)"
    return $grouped
}