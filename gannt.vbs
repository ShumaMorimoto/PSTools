Option Explicit

'================================================================
' クリップボードのデータからガントチャート風オブジェクトを描画 (VBA版)
' v3.4: クリップボード対応・既存図形を削除しない版
'================================================================

' 描画済み矩形の情報を格納するためのユーザー定義型
Private Type RectInfo
    X As Double
    Y As Double
    Width As Double
    Height As Double
End Type

'-----------------------------------------------------------------
' ▼▼▼ 設定項目 ▼▼▼
'-----------------------------------------------------------------

' 1. 描画デザインの設定 (単位はExcelのポイント)
Private Const CHART_RIGHT_MARGIN As Double = 20 ' 描画開始セルとチャート間の右方向の余白
Private Const BOX_HEIGHT As Double = 21          ' 各ボックスの高さ
Private Const UNIT_WIDTH As Double = 24.75       ' 1ヶ月あたりの横幅
Private Const VERTICAL_MARGIN As Double = 3.75   ' 期間が重複する場合の縦の隙間

' 2. 色の設定 (RGB値)
Private Function GetColor(ByVal typeName As String) As Long
    Select Case typeName
        Case "準委任": GetColor = RGB(255, 255, 153) ' 黄色系
        Case "請負":   GetColor = RGB(204, 255, 204) ' 緑色系
        Case Else:     GetColor = RGB(211, 211, 211) ' デフォルト色 (灰色)
    End Select
End Function

'-----------------------------------------------------------------
' ▲▲▲ 設定はここまで ▲▲▲
'-----------------------------------------------------------------



' --- メイン処理 ---
Public Sub CreateGanttChartFromClipboard()
    ' --- 変数宣言 ---
    Dim chartSheet As Worksheet
    Dim dataArray As Variant
    Dim i As Long, j As Long
    Dim drawStartX As Double, drawStartY As Double
    Dim minDate As Date, d As Date
    Dim drawnRects() As RectInfo, rectCount As Long
    Dim shapeNames() As String, shapeCount As Long
    Dim milestoneY As Double
    Dim processName As String, procType As String, startStr As String, endStr As String
    Dim milestoneDate As Date, offsetMonths As Long, milestoneX_end As Double
    Dim milestoneTextBox As shape
    Dim startDate As Date, endDate As Date
    Dim durationMonths As Long, startOffsetMonths As Long
    Dim boxWidth As Double, currentX As Double, currentY As Double
    Dim lastRect As RectInfo, isOverlapping As Boolean
    Dim barShape As shape, textShape As shape, itemGroup As shape, groupShape As shape

    ' --- 描画位置の基準セルを決定 ---
    If typeName(Selection) <> "Range" Then
        MsgBox "描画を開始したい位置のセルを一つ選択してからマクロを実行してください。", vbExclamation
        Exit Sub
    End If
    Set chartSheet = ActiveSheet

    ' --- クリップボードからデータを取得し、2次元配列に変換 ---
    Dim clipboardData As MSForms.DataObject
    Dim clipboardText As String
    Dim lines() As String, columns() As String
    
    Set clipboardData = New MSForms.DataObject
    clipboardData.GetFromClipboard

    On Error Resume Next
    clipboardText = clipboardData.GetText(1)
    If Err.Number <> 0 Then
        MsgBox "クリップボードからテキストデータを取得できませんでした。" & vbCrLf & _
               "描画対象となる表データをコピー（Ctrl+C）してから実行してください。", vbExclamation
        Exit Sub
    End If
    On Error GoTo 0

    If Len(clipboardText) = 0 Then
        MsgBox "クリップボードにテキストデータがありません。" & vbCrLf & _
               "描画対象となる表データをコピーしてください。", vbExclamation
        Exit Sub
    End If
    
    ' 改行コードを統一(LF)して行に分割
    clipboardText = Replace(clipboardText, vbCrLf, vbLf)
    lines = Split(clipboardText, vbLf)
    
    ' 最終行が空行の場合は除外
    If UBound(lines) >= 0 Then
        If lines(UBound(lines)) = "" Then ReDim Preserve lines(0 To UBound(lines) - 1)
    End If
    
    If UBound(lines) < 0 Then
        MsgBox "クリップボードのデータが空です。", vbExclamation
        Exit Sub
    End If
    
    ' データを行と列に分割して2次元配列dataArrayを作成
    Dim numRows As Long, numCols As Long
    numRows = UBound(lines) + 1
    
    ' 1行目の列数に合わせて配列を定義
    numCols = UBound(Split(lines(0), vbTab)) + 1
    If numCols < 4 Then
        MsgBox "データには少なくとも4列（工程名, 種別, 開始日, 終了日）が必要です。", vbExclamation
        Exit Sub
    End If

    ReDim dataArray(1 To numRows, 1 To numCols)
    For i = 0 To UBound(lines)
        columns = Split(lines(i), vbTab)
        For j = 0 To UBound(columns)
            If j < numCols Then
                dataArray(i + 1, j + 1) = columns(j)
            End If
        Next j
    Next i
    
    ' --- 描画座標を決定 ---
    ' アクティブセルの右隣から描画を開始
    drawStartX = ActiveCell.Left + ActiveCell.Width + CHART_RIGHT_MARGIN
    drawStartY = ActiveCell.Top
    
    ' --- 基準日（最も早い開始日）の計算 ---
    minDate = #12/31/9999#
    For i = 1 To UBound(dataArray, 1)
        If UBound(dataArray, 2) >= 3 Then ' 配列の列数が3以上あることを確認
            If dataArray(i, 3) <> "" And CStr(dataArray(i, 2)) <> "マイルストーン" Then
                d = ConvertYYMMToDate(CStr(dataArray(i, 3)))
                If d < minDate Then minDate = d
            End If
        End If
    Next i
    
    If minDate = #12/31/9999# Then
        MsgBox "クリップボードのデータに有効な開始日を持つデータが見つかりませんでした。", vbExclamation
        Exit Sub
    End If
    
    ' --- 描画用変数の初期化 ---
    rectCount = 0
    shapeCount = 0
    milestoneY = -1
    
    ' --- 各データ行をループして図形を描画 ---
    For i = 1 To UBound(dataArray, 1)
        ' 配列の範囲外アクセスを防ぐ
        If UBound(dataArray, 2) >= 4 Then
            processName = CStr(dataArray(i, 1))
            procType = CStr(dataArray(i, 2))
            startStr = CStr(dataArray(i, 3))
            endStr = CStr(dataArray(i, 4))
        Else
            GoTo NextLoop ' データが4列未満の行はスキップ
        End If
        
        If procType = "マイルストーン" Then
            If endStr <> "" Then
                milestoneDate = ConvertYYMMToDate(endStr)
                If milestoneY = -1 Then
                    milestoneY = IIf(rectCount > 0, GetMaxY(drawnRects, rectCount) + BOX_HEIGHT + VERTICAL_MARGIN, drawStartY)
                End If
                
                offsetMonths = GetMonthDifference(minDate, milestoneDate)
                milestoneX_end = drawStartX + ((offsetMonths + 1.5) * UNIT_WIDTH)
                
                Set milestoneTextBox = chartSheet.Shapes.AddTextbox(msoTextOrientationHorizontal, 0, milestoneY, 100, BOX_HEIGHT)
                ' ★削除: 個別のPlacement設定は不要
                With milestoneTextBox
                    .TextFrame2.TextRange.Text = processName & "('" & Format(milestoneDate, "yy/mm") & ")▲"
                    .TextFrame2.AutoSize = msoAutoSizeShapeToFitText
                    .Fill.Visible = msoFalse
                    .line.Visible = msoFalse
                    .Left = milestoneX_end - .Width
                    
                    shapeCount = shapeCount + 1
                    ReDim Preserve shapeNames(1 To shapeCount)
                    shapeNames(shapeCount) = .Name
                End With
            End If
        ElseIf startStr <> "" And endStr <> "" Then
            startDate = ConvertYYMMToDate(startStr)
            endDate = ConvertYYMMToDate(endStr)
            
            durationMonths = GetMonthDifference(startDate, endDate)
            startOffsetMonths = GetMonthDifference(minDate, startDate) - 1
            
            boxWidth = durationMonths * UNIT_WIDTH
            currentX = drawStartX + (startOffsetMonths * UNIT_WIDTH)
            
            ' Y座標の決定 (重複チェック)
            currentY = drawStartY
            If rectCount > 0 Then
                lastRect = drawnRects(rectCount)
                isOverlapping = (currentX < (lastRect.X + lastRect.Width)) And ((currentX + boxWidth) > lastRect.X)
                If isOverlapping Then
                    currentY = lastRect.Y + BOX_HEIGHT + VERTICAL_MARGIN
                Else
                    currentY = lastRect.Y
                End If
            End If
            
            Set barShape = chartSheet.Shapes.AddShape(msoShapeRectangle, currentX, currentY, boxWidth, BOX_HEIGHT)
            ' ★削除: 個別のPlacement設定は不要
            barShape.Fill.ForeColor.RGB = GetColor(procType)
            barShape.line.Visible = msoTrue

            Set textShape = chartSheet.Shapes.AddTextbox(msoTextOrientationHorizontal, currentX, currentY, boxWidth, BOX_HEIGHT)
            ' ★削除: 個別のPlacement設定は不要
            With textShape
                .Fill.Visible = msoFalse
                .line.Visible = msoFalse
                
                ' テキスト幅の測定
                Dim textActualWidth As Double
                Dim dummyTextBox As shape
                
                Set dummyTextBox = chartSheet.Shapes.AddTextbox(msoTextOrientationHorizontal, -1000, -1000, 10, 10)
                With dummyTextBox
                    .TextFrame2.WordWrap = msoFalse
                    .TextFrame2.TextRange.Text = processName
                    .TextFrame2.AutoSize = msoAutoSizeShapeToFitText
                    textActualWidth = .Width
                    .Delete
                End With

                With .TextFrame2
                    .TextRange.Text = processName
                    .TextRange.Font.Fill.ForeColor.RGB = RGB(0, 0, 0)
                    .VerticalAnchor = msoAnchorMiddle
                    .AutoSize = msoAutoSizeNone
                    .WordWrap = msoFalse

                    If textActualWidth > boxWidth Then
                        .TextRange.ParagraphFormat.Alignment = msoAlignLeft
                    Else
                        .TextRange.ParagraphFormat.Alignment = msoAlignCenter
                    End If
                End With
            End With

            ' バーとテキストをグループ化
            Set itemGroup = chartSheet.Shapes.Range(Array(barShape.Name, textShape.Name)).Group
            
            rectCount = rectCount + 1
            ReDim Preserve drawnRects(1 To rectCount)
            drawnRects(rectCount).X = currentX
            drawnRects(rectCount).Y = currentY
            drawnRects(rectCount).Width = boxWidth
            drawnRects(rectCount).Height = BOX_HEIGHT
            
            shapeCount = shapeCount + 1
            ReDim Preserve shapeNames(1 To shapeCount)
            shapeNames(shapeCount) = itemGroup.Name
        End If
NextLoop:
    Next i
    
    ' --- 描画したすべての図形をグループ化 ---
    If shapeCount > 0 Then
        Set groupShape = chartSheet.Shapes.Range(shapeNames).Group
        groupShape.Placement = xlFreeFloating ' ★追加: 最終的なグループオブジェクトにプロパティを設定
        
        ' グループ名を一意にするため、日付と時刻をサフィックスとして追加
        groupShape.Name = "GanttChartGroup_" & Format(Now, "yyyymmdd_hhmmss")
        groupShape.Select
        
        MsgBox "完了：図形をグループ化しました。", vbInformation
    Else
        MsgBox "描画するデータがありませんでした。", vbExclamation
    End If
    
End Sub

' --- 補助関数 (元のコードから変更なし) ---
Private Function ConvertYYMMToDate(ByVal dateStr As String) As Date
    Dim parts() As String
    Dim yearVal As Long, monthVal As Long
    
    On Error GoTo ErrorHandler
    
    ' 最優先: "YY/MM" 形式の文字列を強制的に解釈する
    If InStr(dateStr, "/") > 0 Then
        parts = Split(dateStr, "/")
        If UBound(parts) = 1 And IsNumeric(parts(0)) And IsNumeric(parts(1)) Then
            yearVal = CLng(parts(0))
            monthVal = CLng(parts(1))
            
            If monthVal >= 1 And monthVal <= 12 Then
                ConvertYYMMToDate = DateSerial(2000 + yearVal, monthVal, 1)
                Exit Function
            End If
        End If
    End If
    
    ' フォールバック: Excelが認識する標準的な日付か試す
    If IsDate(dateStr) Then
        ConvertYYMMToDate = CDate(dateStr)
        Exit Function
    End If

ErrorHandler:
    MsgBox "日付の形式が不正です: '" & dateStr & "'" & vbCrLf & _
           "「YY/MM」（例: 24/04）の形式で入力してください。", vbCritical
    End
End Function

Private Function GetMonthDifference(ByVal date1 As Date, ByVal date2 As Date) As Long
    GetMonthDifference = DateDiff("m", date1, date2) + 1
End Function

Private Function GetMaxY(ByRef rects() As RectInfo, ByVal count As Long) As Double
    Dim maxY As Double, i As Long
    maxY = 0
    For i = 1 To count
        If rects(i).Y > maxY Then maxY = rects(i).Y
    Next i
    GetMaxY = maxY
End Function

