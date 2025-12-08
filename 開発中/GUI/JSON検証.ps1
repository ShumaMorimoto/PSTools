class EntryBase {
    EntryBase() { }

    EntryBase([hashtable]$json) {
        if ($null -ne $json) { $this.ApplyJson($json) }
    }

    [void] ApplyJson([hashtable]$json) {
        foreach ($k in $json.Keys) {
            if ($this.PSObject.Properties.Name -contains $k) {
                $this.$k = $json[$k]
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

class PlaceEntry : EntryBase {
    [string]$名称
    [double]$経度
    [double]$緯度

    PlaceEntry([hashtable]$json) : base($json) { }
}

# --- 検証 ---
$json = @{ 名称="横須賀拠点"; 経度=139.672; 緯度=35.281 }
$p = [PlaceEntry]::new($json)

$p.GetType().Name   # → "PlaceEntry"
$p.名称             # → "横須賀拠点"
$p.経度             # → 139.672
$p.緯度             # → 35.281

$p.ToJson() | ConvertTo-Json -Compress
# → {"名称":"横須賀拠点","経度":139.672,"緯度":35.281}