@{
    # モジュール識別情報
    RootModule        = 'ModuleTools.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'  # New-Guid で生成

    # 作成者情報
    Author            = '修馬'
    CompanyName       = ''
    Description       = 'PowerShell モジュールの分割と統合を支援する開発ツール'

    # PowerShell要件
    PowerShellVersion = '5.1'

    # エクスポート対象
    FunctionsToExport = @('Split-Module', 'Build-Module', 'Get-ClassDependencyTree')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # その他
    PrivateData       = @{}
}