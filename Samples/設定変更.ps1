Get-ExecutionPolicy
Get-ExecutionPolicy -List
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

Get-Module -ListAvailable
Get-Module -ListAvailable -All

Get-Command -ListImported 
Get-Command -Module myModule

using module "./ConfluDAO.psm1"


function Test-ModuleInstalled {
    param (
        [System.String]$ModuleName
    )

    $moduleInstalled = $false

    # モジュール情報を取得
    $module = (Get-Module -ListAvailable -Name $ModuleName)
    # モジュールが導入済みの場合
    if ($null -ne $module) {
        $moduleInstalled = $true
    }
    
    return $moduleInstalled
}