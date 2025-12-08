class EntryBase {
    EntryBase() { }

    EntryBase([object]$json) {
        if ($null -eq $json) { return }

        switch ($json.GetType().Name) {
            'Hashtable' {
                $this.ApplyHashtable([hashtable]$json)
            }
            'PSCustomObject' {
                $this.ApplyPsObject([psobject]$json)
            }
            default {
                throw "Unsupported type: $($json.GetType().FullName)"
            }
        }
    }

    [void] ApplyHashtable([hashtable]$json) {
        foreach ($k in $json.Keys) {
            if ($this.PSObject.Properties.Name -contains $k) {
                $this.PSObject.Properties[$k].Value = $json[$k]
            }
        }
    }

    [void] ApplyPsObject([psobject]$json) {
        foreach ($p in $json.PSObject.Properties) {
            if ($this.PSObject.Properties.Name -contains $p.Name) {
                $this.PSObject.Properties[$p.Name].Value = $p.Value
            }
        }
    }

    [hashtable] ToJson() {
        $ht = @{}
        foreach ($p in $this.PSObject.Properties) {
            if ($p.Name.StartsWith("_")) { continue }
            $ht[$p.Name] = $p.Value
        }
        return $ht
    }
}

