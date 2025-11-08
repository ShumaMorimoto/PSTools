function Split-Gpx {
    param (
        [xml]$GpxXml,
        [double]$DistanceKm = 0.0,
        [int]$PointLimit = 0
    )

    $trkpts = $GpxXml.gpx.trk.trkseg.trkpt
    if (-not $trkpts -or $trkpts.Count -lt 2) {
        Write-Warning "trkptが不足しています。分割できません。"
        return @()
    }

    $segments = @()
    $currentSegment = @()
    $currentDistance = 0.0

    for ($i = 0; $i -lt $trkpts.Count - 1; $i++) {
        $pt1 = $trkpts[$i]
        $pt2 = $trkpts[$i + 1]

        $currentSegment += $pt1
        $dist = Get-Distance $pt1 $pt2
        $currentDistance += $dist

        $shouldSplit = $false
        if ($DistanceKm -gt 0 -and $currentDistance -ge $DistanceKm) {
            $shouldSplit = $true
        }
        elseif ($PointLimit -gt 0 -and $currentSegment.Count -ge $PointLimit) {
            $shouldSplit = $true
        }

        if ($shouldSplit) {
            $currentSegment += $pt2
            $segments += @{ Points = $currentSegment; Distance = $currentDistance }
            $currentSegment = @()
            $currentDistance = 0.0
        }
    }

    if ($currentSegment.Count -gt 0) {
        $currentSegment += $trkpts[-1]
        $segments += @{ Points = $currentSegment; Distance = $currentDistance }
    }

    # GPX XMLリストを構築
    $gpxList = @()
    $segmentIndex = 1

    foreach ($segment in $segments) {
        $trkptNodes = $segment.Points
        $distance = [math]::Round($segment.Distance, 2)
        $count = $trkptNodes.Count

        $xml = New-GpxFromTrkpt `
            -TrkptNodes $trkptNodes `
            -TrackName "Segment $segmentIndex" `
            -TotalDistanceKm $distance `
            -PointCount $count

        $gpxList += $xml
        $segmentIndex++
    }

    return $gpxList
}