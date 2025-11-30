function Compare-ModuleFolders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,   # ソースフォルダ

        [Parameter(Mandatory = $true)]
        [string]$TargetDir,   # ターゲットフォルダ

        [Parameter()]
        [string]$ReportPath = (Join-Path $PWD "ModuleDiffReport.txt") # 出力ファイル
    )

    $resolvedSource = Resolve-Path $SourceDir
    $resolvedTarget = Resolve-Path $TargetDir

    if (-not (Test-Path $resolvedSource)) {
        Write-Error "❌ ソースフォルダが存在しません: $SourceDir"
        return
    }
    if (-not (Test-Path $resolvedTarget)) {
        Write-Error "❌ ターゲットフォルダが存在しません: $TargetDir"
        return
    }

    # 出力ファイル初期化
    "📊 モジュール差分レポート" | Out-File $ReportPath -Encoding UTF8
    "ソース: $resolvedSource"   | Out-File $ReportPath -Append
    "ターゲット: $resolvedTarget" | Out-File $ReportPath -Append
    "生成日時: $(Get-Date)"     | Out-File $ReportPath -Append
    "=====================================" | Out-File $ReportPath -Append

    # ファイル一覧を取得
    $srcFiles = Get-ChildItem -Path $resolvedSource -Recurse -File |
        ForEach-Object {
            [PSCustomObject]@{
                RelPath   = $_.FullName.Substring($resolvedSource.Path.Length)
                FullPath  = $_.FullName
                LastWrite = $_.LastWriteTime
            }
        }

    $dstFiles = Get-ChildItem -Path $resolvedTarget -Recurse -File |
        ForEach-Object {
            [PSCustomObject]@{
                RelPath   = $_.FullName.Substring($resolvedTarget.Path.Length)
                FullPath  = $_.FullName
                LastWrite = $_.LastWriteTime
            }
        }

    $allRelPaths = $srcFiles.RelPath + $dstFiles.RelPath | Sort-Object -Unique
    $folders = $allRelPaths | ForEach-Object { Split-Path $_ -Parent } | Sort-Object -Unique

    foreach ($folder in $folders) {
        "`n📂 $folder" | Out-File $ReportPath -Append
        "──────────────────────────────" | Out-File $ReportPath -Append

        # ソースのみ → ファイル出力
        $onlySrc = $srcFiles | Where-Object {
            $_.RelPath -like "$folder*" -and
            -not ($dstFiles.RelPath -contains $_.RelPath)
        }
        if ($onlySrc) {
            "✅ ソースにのみ存在:" | Out-File $ReportPath -Append
            $onlySrc | ForEach-Object {
                ("  {0}   ({1} → なし)" -f (Split-Path $_.RelPath -Leaf), $_.LastWrite) |
                    Out-File $ReportPath -Append
            }
        }

        # ターゲットのみ → ファイル出力
        $onlyDst = $dstFiles | Where-Object {
            $_.RelPath -like "$folder*" -and
            -not ($srcFiles.RelPath -contains $_.RelPath)
        }
        if ($onlyDst) {
            "⚠️ ターゲットにのみ存在:" | Out-File $ReportPath -Append
            $onlyDst | ForEach-Object {
                ("  {0}   (なし → {1})" -f (Split-Path $_.RelPath -Leaf), $_.LastWrite) |
                    Out-File $ReportPath -Append
            }
        }

        # 中身が異なるファイル → 標準出力のみ
        $common = $srcFiles | Where-Object { $_.RelPath -like "$folder*" } |
            ForEach-Object {
                $dst = $dstFiles | Where-Object { $_.RelPath -eq $_.RelPath }
                if ($dst) {
                    $srcHash = (Get-FileHash $_.FullPath -Algorithm SHA256).Hash
                    $dstHash = (Get-FileHash $dst.FullPath -Algorithm SHA256).Hash
                    if ($srcHash -ne $dstHash) {
                        [PSCustomObject]@{
                            Name    = Split-Path $_.RelPath -Leaf
                            SrcTime = $_.LastWrite
                            DstTime = $dst.LastWrite
                        }
                    }
                }
            }

        if ($common) {
            Write-Host "`n📂 $folder" -ForegroundColor Cyan
            Write-Host "⚠️ 中身が異なるファイル:" -ForegroundColor Yellow
            $common | ForEach-Object {
                Write-Host ("  {0}   ({1} → {2})" -f $_.Name, $_.SrcTime, $_.DstTime)
            }
        }
    }

    Write-Host "📄 存在差分レポートを保存しました: $ReportPath" -ForegroundColor Green
}