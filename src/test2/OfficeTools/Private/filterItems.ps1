filterItems([Object]$items, [Object]$keywords) { 
        $filter = "@SQL=urn:schemas:httpmail:subject LIKE '" + [string]::Join("' OR urn:schemas:httpmail:subject LIKE '", $keywords) + "'" 
        return $items.Restrict($filter)
    }
