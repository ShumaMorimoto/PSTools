function Draw-Route {
        param ($gen, $route, $distance)

        $bitmap = New-Object Drawing.Bitmap $form.Width, $form.Height
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([Drawing.Color]::White)

        # 線描画
        for ($i = 0; $i -lt $route.Count; $i++) {
            $pt1 = Convert-ToXY $route[$i].Lat $route[$i].Lon
            $pt2 = Convert-ToXY $route[($i + 1) % $route.Count].Lat $route[($i + 1) % $route.Count].Lon
            $graphics.DrawLine([Drawing.Pens]::Blue, $pt1.X, $pt1.Y, $pt2.X, $pt2.Y)
        }

        # 地点描画
        foreach ($pt in $route) {
            $xy = Convert-ToXY $pt.Lat $pt.Lon
            $graphics.FillEllipse([Drawing.Brushes]::Red, $xy.X - 4, $xy.Y - 4, 8, 8)
            $graphics.DrawString($pt.Name, [Drawing.Font]::new("Arial", 8), [Drawing.Brushes]::Black, $xy.X + 5, $xy.Y - 10)
        }

        # 世代と距離の表示
        $graphics.DrawString("世代 $gen - 距離: $([math]::Round($distance, 2)) km", [Drawing.Font]::new("Arial", 12), [Drawing.Brushes]::Black, 20, 20)

        $pictureBox.Image = $bitmap
        $form.Refresh()
        Start-Sleep -Milliseconds 300
    }
