# ファイルパスの設定
$exportedUI = "C:\Users\shuma\OneDrive\ドキュメント\Excel Customizations.exportedUI"
$xlamFile = "D:\tool\Repository\PSTools\src\regAddin\custom.xlam"
$tempFolder = "$env:TEMP\addin_temp"

# 一時フォルダを作成
Remove-Item -Recurse -Force $tempFolder -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tempFolder | Out-Null

# アドインを展開
Expand-Archive -Path $xlamFile -DestinationPath $tempFolder

# customUI フォルダを作成（なければ）
$customUIFolder = Join-Path $tempFolder "customUI"
New-Item -ItemType Directory -Path $customUIFolder -Force | Out-Null

# exportedUI を customUI.xml にコピー
Copy-Item -Path $exportedUI -Destination (Join-Path $customUIFolder "customUI.xml") -Force

# 再圧縮してアドインを更新
$updatedXlam = "D:\tool\Repository\PSTools\src\regAddin\custom3.xlam"
Compress-Archive -Path "$tempFolder\*" -DestinationPath $updatedXlam -Force

# 後処理
Remove-Item -Recurse -Force $tempFolder