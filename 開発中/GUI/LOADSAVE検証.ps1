Add-Type -AssemblyName PresentationFramework

# --- EntryBase (object分岐版) ---
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

# --- UserEntry ---
class UserEntry : EntryBase {
    [string]$Name
    [int]$Age
    [datetime]$RegisteredAt
    UserEntry([object]$json) : base($json) { }
}

# --- Save/Load 関数 ---
function Save-History {
    param([System.Windows.Controls.ComboBox]$cb)
    $file = $cb.Tag.HistoryFile
    $hist = $cb.Tag.History
    $jsonList = @()
    foreach ($h in $hist) {
        $selectedJson = @()
        foreach ($s in $h.Selected) {
            $selectedJson += $s.ToJson()
        }
        $jsonList += @{
            Keyword  = $h.Keyword
            Selected = $selectedJson
            lastUsed = $h.lastUsed
        }
    }
    $jsonList | ConvertTo-Json -Depth 10 -Compress | Out-File $file -Encoding UTF8
}

function Load-History {
    param([System.Windows.Controls.ComboBox]$cb)
    $file = $cb.Tag.HistoryFile
    $entries = @()
    if (Test-Path $file) {
        try {
            $json = Get-Content $file -Raw | ConvertFrom-Json
            foreach ($o in $json) {
                $cls = $cb.Tag.EntryClass
                $selected = [System.Collections.Generic.List[object]]::new()
                foreach ($s in $o.Selected) {
                    $selected.Add($cls::new($s))   # ← objectで受けられるのでOK
                }
                $entries += @{
                    Keyword  = $o.Keyword
                    Selected = $selected
                    lastUsed = $o.lastUsed
                }
            }
        }
        catch { $entries = @() }
    }
    $cb.Tag.History = $entries
}

# --- テストコード ---
$cb = [System.Windows.Controls.ComboBox]::new()
$cb.Tag = @{
    HistoryFile = "$env:TEMP\user_history_test.json"
    EntryClass  = [UserEntry]
    History     = @()
}

# ダミー履歴データ作成
$u1 = [UserEntry]::new(@{ Name="修馬"; Age=35; RegisteredAt=(Get-Date "2025-12-07T04:33:00") })
$u2 = [UserEntry]::new(@{ Name="太郎"; Age=28; RegisteredAt=(Get-Date "2025-12-07T04:34:00") })

$cb.Tag.History = @(
    @{
        Keyword  = "ユーザ検索"
        Selected = [System.Collections.Generic.List[object]]@($u1, $u2)
        lastUsed = (Get-Date)
    }
)

# 保存
Save-History $cb
Write-Host "保存完了: $($cb.Tag.HistoryFile)"

# 読み込み
$cb.Tag.History = @()
Load-History $cb

# 検証出力
foreach ($h in $cb.Tag.History) {
    Write-Host "Keyword: $($h.Keyword)"
    Write-Host "lastUsed: $($h.lastUsed)"
    foreach ($s in $h.Selected) {
        Write-Host "  Name=$($s.Name) Age=$($s.Age) RegisteredAt=$($s.RegisteredAt)"
    }
}