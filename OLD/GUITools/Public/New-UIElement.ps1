function New-UIElement {
    param(
        [string]$ElementKey,
        [string]$XamlFile = "Controls.xaml"
    )

    $xamlPath = Join-Path $script:ModuleRoot "data\$XamlFile"
    if (-not (Test-Path $xamlPath)) {
        throw "XAMLファイルが見つかりません: $xamlPath"
    }

    [xml]$xaml = Get-Content $xamlPath
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $dict = [Windows.Markup.XamlReader]::Load($reader)

    return $dict[$ElementKey]
}