# ConvertTo-ScriptDefinition.ps1
# ドットソースして関数を定義するためのファイル（ファイル先頭に param を置かない）

function ConvertTo-ScriptDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [object[]] $Path,

        [int] $Depth = 5
    )

    Begin {
        $scriptDefs = @()
    }

    Process {
        foreach ($p in $Path) {
            # 絶対パス解決
            try {
                if ($p -is [System.IO.FileInfo]) {
                    $fullPath = $p.FullName
                }
                elseif ($p -is [System.Management.Automation.PSObject] -and $p.PSObject.Properties.Match('FullName')) {
                    $fullPath = $p.FullName
                }
                else {
                    $fullPath = (Resolve-Path -LiteralPath $p -ErrorAction Stop).ProviderPath
                }
            }
            catch {
                Write-Warning "パス解決失敗、スキップ: $p"
                continue
            }

            if (-not (Test-Path -LiteralPath $fullPath)) {
                Write-Warning "ファイルが存在しません: $fullPath"
                continue
            }
            $fi = Get-Item -LiteralPath $fullPath
            if ($fi.PSIsContainer) {
                Write-Verbose "ディレクトリはスキップ: $fullPath"
                continue
            }

            # AST 解析
            try {
                $errors = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$null, [ref]$errors)
            }
            catch {
                Write-Warning "AST 解析エラー: $fullPath"
                continue
            }

            # synopsis
            $synopsis = ''
            try {
                $h = Get-Help -LiteralPath $fullPath -ErrorAction SilentlyContinue
                if ($h -and $h.Synopsis) { $synopsis = $h.Synopsis }
            }
            catch {}
            if (-not $synopsis -and $ast.HelpComments) {
                foreach ($hc in $ast.HelpComments) {
                    if ($hc.Text -match '^\s*#\s*\.SYNOPSIS\s+(.+)$') {
                        $synopsis = $matches[1].Trim()
                        break
                    }
                }
            }

            # params
            $paramList = @()
            if ($ast.ParamBlock) {
                foreach ($pAst in $ast.ParamBlock.Parameters) {
                    $name = $pAst.Name.VariablePath.UserPath

                    $rawType = 'String'
                    if ($pAst.TypeName) {
                        try { $rawType = $pAst.TypeName.GetReflectionType().Name } catch {}
                    }

                    $type = switch ($rawType) {
                        'String' { 'String' }
                        'Int32' { 'Int' }
                        'Int64' { 'Int' }
                        'Double' { 'Double' }
                        'Single' { 'Double' }
                        'Boolean' { 'Bool' }
                        'SwitchParameter' { 'Switch' }
                        default { 'String' }
                    }

                    $required = $false
                    foreach ($attr in $pAst.Attributes) {
                        if ($attr.TypeName.Name -eq 'Parameter') {
                            foreach ($na in $attr.NamedArguments) {
                                if ($na.Name -eq 'Mandatory') {
                                    try { $required = [bool]($na.Argument.GetValue()) } catch {}
                                }
                            }
                        }
                    }

                    $default = ''
                    if ($pAst.DefaultValue) { $default = $pAst.DefaultValue.Extent.Text.Trim() }

                    $filter = $null
                    if ($type -eq 'String') {
                        if ($name -match '(?i)(File|Path|Gpx)$') {
                            $type = 'File'
                            $filter = $name -match '(?i)gpx' ? 'GPX Files|*.gpx|All Files|*.*' : 'All Files|*.*'
                        }
                        elseif ($name -match '(?i)(Dir|Folder|Directory)') {
                            $type = 'Folder'
                        }
                        elseif ($default -match '\*\.[a-z0-9]+') {
                            $type = 'File'
                            $ext = ($matches[0] -replace '^\*\.', '')
                            $filter = "$($ext.ToUpper()) Files|*.$ext|All Files|*.*"
                        }
                    }

                    $paramList += [PSCustomObject]@{
                        Name     = $name
                        Type     = $type
                        Label    = $name
                        Default  = $default
                        Filter   = $filter
                        Required = $required
                    }
                }
            }

            $scriptDefs += [PSCustomObject]@{
                Name        = (Split-Path -Path $fullPath -LeafBase)
                ScriptPath  = $fullPath
                Description = $synopsis
                Color       = 'LightSlateGray'
                Params      = $paramList
            }
        }
    }

    End {
        $scriptDefs | ConvertTo-Json -Depth $Depth
    }
}

# ドットソース時に不要な実行をしないよう、ここでは何も実行しない。
# 実行例:
# . 'C:\path\ConvertTo-ScriptDefinition.ps1'     # これで関数が定義される
# Get-Item .\SomeScript.ps1 | ConvertTo-ScriptDefinition
