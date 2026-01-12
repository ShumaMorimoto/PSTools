# TestModule.psm1
function Get-TestMessage {
    return "モジュールは正常にロードされました"
}


$TestRoutes = @{
    Start = {
        param($data, $rh)
        $rh.Start($data)
    }
    Status = {
        param($data, $rh)
        return @{
            Generation = $rh.State.Generation
            UpdatedAt  = $rh.State.UpdatedAt
            TestResult = $rh.State.TestResult
        }
    }
    Stop = {
        param($data, $rh)
        $rh.Stop()
    }
}
$TestStartScript = {
    param($State, $data)

    # モジュール関数が呼べるかテスト
    $msg = Get-TestMessage

    $State.Generation = 1
    $State.UpdatedAt  = Get-Date
    $State.TestResult = $msg

    Start-Sleep -Seconds 1
}


Run-App `
    -ModulePath "D:\tool\Repository\PSTools\開発中\GPX3\TestModule.psm1" `
    -StartScript $TestStartScript `
    -InitialData @{ test = 1 } `
    -Routes $TestRoutes `
    -PageName "D:\tool\Repository\PSTools\開発中\GPX3\sample3.html"