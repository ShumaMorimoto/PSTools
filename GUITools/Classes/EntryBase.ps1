class EntryBase {
    EntryBase() { }
<<<<<<< Updated upstream

    EntryBase([hashtable]$json) {
        if ($null -eq $json) { return }
        $this.ApplyHashtable($json)
    }

    EntryBase([psobject]$json) {
        if ($null -eq $json) { return }
        $this.ApplyPsObject($json)
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
=======
    [bool] Equals([object] $other) { throw "Equals must be implemented in derived class" }
    [string] ToJson() { return ($this | ConvertTo-Json -Compress) }
    static [EntryBase] FromJson([object]$obj) { throw "FromJson must be implemented in derived class" }
}
>>>>>>> Stashed changes
