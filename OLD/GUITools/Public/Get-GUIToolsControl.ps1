function Get-GUIToolsControl {
    <#
    .SYNOPSIS
        GUITools モジュールから Controls.xaml をロードし、指定したコンポーネントを返す

    .DESCRIPTION
        Controls.xaml 内のリソース辞書をロードし、指定されたキー名のコンポーネントを返します。
        Controls.xaml は 1 ファイルに複数のコンポーネントを定義しているため、
        必要なコンポーネント名を指定して取り出す設計です。

    .PARAMETER ControlName
        Controls.xaml 内のキー名。例: "SearchCombo"

    .EXAMPLE
        $searchCombo = Get-GUIToolsControl -ControlName "SearchCombo"
        ($window.FindName("SearchComboHost")).Content = $searchCombo
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ControlName
    )

    # Controls.xaml のパスを組み立て
    $controlsPath = Join-Path $script:ModuleRoot "data\Controls.xaml"

    # 存在チェック
    if (-not (Test-Path $controlsPath)) {
        throw "Controls.xaml が見つかりません: $controlsPath"
    }

    # Controls.xaml をロード
    [xml]$controlsXml = Get-Content $controlsPath
    $reader = New-Object System.Xml.XmlNodeReader $controlsXml
    $dict = [System.Windows.Markup.XamlReader]::Load($reader)

    # 指定されたコンポーネントが存在するか確認
    if (-not $dict.Contains($ControlName)) {
        throw "Controls.xaml に '$ControlName' が見つかりません"
    }

    # コンポーネントを返す
    return $dict[$ControlName]
}