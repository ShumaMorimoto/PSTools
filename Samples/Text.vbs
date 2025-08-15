Option Explicit

' --- 1. 設定 ---
Const PS_SCRIPT_PATH = "H:\tool\アドレス取得.ps1"
Dim keyword: keyword = "山田"

' --- 2. 準備 ---
Dim fso, shell, tempFolder, tempFilePath, command, exitCode
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
tempFolder = fso.GetSpecialFolder(2)
tempFilePath = fso.BuildPath(tempFolder, fso.GetTempName())
' WScript.Echo "一時ファイルパス: " & tempFilePath ' デバッグ時はコメントを外す

' --- 3. PowerShell実行コマンドの組み立て ---
command = "cmd.exe /c ""chcp 65001 > nul & pwsh.exe -ExecutionPolicy Bypass -NoProfile -File """ & PS_SCRIPT_PATH & """ -keyword """ & keyword & """ > """ & tempFilePath & """"""
' WScript.Echo "実行コマンド: " & command ' デバッグ時はコメントを外す

' --- 4. コマンドを実行し、終了を待つ ---
exitCode = shell.Run(command, 0, True)

' --- 5. 結果ファイルの読み込みと処理 ---
Dim content, stream

If exitCode = 0 And fso.FileExists(tempFilePath) Then
    Set stream = CreateObject("ADODB.Stream")
    
    ' ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
    ' ★
    ' ★             ここが最も重要な修正点です
    ' ★
    ' ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

    ' これから読み込むデータはテキスト形式であると設定
    stream.Type = 2 ' adTypeText

    ' 【重要】ファイルの文字コードを明示的に「UTF-8」に指定する
    ' これにより、文字化けを確実に防ぎます。
    stream.Charset = "utf-8"

    ' ストリームを開く
    stream.Open
    
    ' ファイルからストリームにデータを読み込む
    stream.LoadFromFile tempFilePath
    
    ' ストリームから全てのテキストを読み込む
    content = stream.ReadText(-1) ' adReadAll
    
    stream.Close
    
    ' 取得した内容をメッセージボックスで表示
    MsgBox "PowerShellから取得した内容：" & vbCrLf & content, vbInformation, "成功"

Else
    ' 失敗した場合の処理
    MsgBox "PowerShellの実行に失敗しました。" & vbCrLf & "ExitCode: " & exitCode, vbCritical, "エラー"
End If


' --- 6. 後始末 ---
If fso.FileExists(tempFilePath) Then
    fso.DeleteFile tempFilePath
End If

Set fso = Nothing
Set shell = Nothing
Set stream = Nothing

' WScript.Echo "処理が完了しました。"

