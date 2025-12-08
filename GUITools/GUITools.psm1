#モジュールルートの設定
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─── DLL 読み込み ───
if (Test-Path "$PSScriptRoot\lib") {
    Get-ChildItem "$PSScriptRoot\lib\*.dll" | ForEach-Object {
        Add-Type -Path $_.FullName
    }
}

# ─── クラス定義 ───
Add-Type -AssemblyName PresentationFramework

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



# ─── 関数読み込み ───
foreach ($folder in @('Common', 'Extensions', 'Private', 'Public')) {
    if (Test-Path "$PSScriptRoot\$folder") {
        Get-ChildItem "$PSScriptRoot\$folder\*.ps1" | ForEach-Object {
            . $_.FullName
        }
    }
}

# ─── 公開関数 ───
$publicFunctions = @()
if (Test-Path "$PSScriptRoot\Public") {
    $publicFunctions = Get-ChildItem "$PSScriptRoot\Public\*.ps1" | ForEach-Object {
        [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    }
}
Export-ModuleMember -Function $publicFunctions

# ─── モジュール初期化 ───
Enable-ModuleSettings
