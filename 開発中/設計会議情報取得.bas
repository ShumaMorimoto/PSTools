Attribute VB_Name = "Module1"
' 参照設定が必要：
' - Microsoft Forms 2.0 Object Library
' - Microsoft Scripting Runtime（推奨）

Function DictionaryToJson(dict As Scripting.Dictionary) As String
    Dim json As String
    json = "{"
    Dim key As Variant
    For Each key In dict.Keys
        json = json & """" & key & """:""" & Replace(dict(key), """", "\""") & ""","
    Next key
    If Right(json, 1) = "," Then
        json = Left(json, Len(json) - 1)
    End If
    json = json & "}"
    DictionaryToJson = json
End Function

Function BuildDataDictionary(ws As Worksheet, rowNum As Long) As Scripting.Dictionary
    Dim dict As Scripting.Dictionary
    Set dict = New Scripting.Dictionary

    Dim 担当 As String
    Dim 開催日 As String
    Dim 顧客名 As String
    Dim ファイル名 As String

    担当 = Trim(ws.Cells(rowNum, "A").value)
    開催日 = Trim(ws.Cells(rowNum, "D").value)
    顧客名 = Trim(ws.Cells(rowNum, "E").value)

    Dim 開催日フォーマット As String
    If IsDate(開催日) Then
        開催日フォーマット = Format(CDate(開催日), "yyyymmdd")
    Else
        開催日フォーマット = ""
    End If

    ファイル名 = 顧客名 & "_" & 開催日フォーマット

    dict.Add "担当", 担当
    dict.Add "開催日", 開催日
    dict.Add "顧客名", 顧客名
    dict.Add "ファイル名", ファイル名

    ' JSON化して "json" キーに追加
    dict.Add "json", DictionaryToJson(dict)

    Set BuildDataDictionary = dict
End Function

Function ReplaceTemplateWithDictionary(template As String, dict As Scripting.Dictionary) As String
    Dim key As Variant
    For Each key In dict.Keys
        template = Replace(template, "<" & key & ">", dict(key))
    Next key
    ReplaceTemplateWithDictionary = template
End Function

Sub 設計会議情報取得()
    Dim ws As Worksheet
    Set ws = ActiveSheet

    Dim rowNum As Long
    rowNum = ActiveCell.Row

    Dim dict As Scripting.Dictionary
    Set dict = BuildDataDictionary(ws, rowNum)

    Dim DataObj As New DataObject
    On Error Resume Next
    DataObj.GetFromClipboard
    Dim rawText As String
    rawText = DataObj.GetText
    On Error Goto 0

        Dim outputText As String
        If Len(Trim(rawText)) = 0 Then
            outputText = dict("json")
        Else
            outputText = ReplaceTemplateWithDictionary(rawText, dict)
        End If

        DataObj.SetText outputText
        DataObj.PutInClipboard

        MsgBox "コピーしました。" & vbCrLf & outputText
End Sub
