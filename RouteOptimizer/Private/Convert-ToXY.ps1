function Convert-ToXY($lat, $lon) {
        $x = ($lon - $minLon) / ($maxLon - $minLon) * ($form.Width - 40) + 20
        $y = ($maxLat - $lat) / ($maxLat - $minLat) * ($form.Height - 40) + 20
        return @{ X = [int]$x; Y = [int]$y }
    }
