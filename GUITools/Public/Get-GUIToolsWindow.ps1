function Get-GUIToolsWindow {
    <#
    .SYNOPSIS
        GUITools モジュールから指定した Window XAML をロードして返す

    .DESCRIPTION
        psm1 の先頭で宣言されている $script:ModuleRoot を利用して、
        モジュール内の data フォルダから指定された Window の XAML を読み込みます。
        複数のウィンドウ (MainWindow.xaml, SubWindow.xaml など) に対応可能です。

    .PARAMETER WindowName
        XAMLファイル名（拡張子なし）。例: "MainWindow"

    .EXAMPLE
        $window = Get-GUIToolsWindow -WindowName "MainWindow"
        $window.ShowDialog() | Out-Null
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowName
    )

    # モジュールルートから対象 XAML のパスを組み立て
    $path = Join-Path $script:ModuleRoot "data\$WindowName.xaml"

    # 存在チェック
    if (-not (Test-Path $path)) {
        throw "指定された Window '$WindowName' の XAML が見つかりません: $path"
    }

    # XAML をロードして返す
    [xml]$xaml = Get-Content $path
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    return [System.Windows.Markup.XamlReader]::Load($reader)
}