using module OfficeTools
param(
  [string]$keyword 
)

[Console]::OutputEncoding = [System.Text.Encoding]::Default

function getAddress([string]$keyword) {
  $url = "http://nricis1.wwws.nri.co.jp/cgi-bin/telgate17.pl?keywords=" + [SYstem.Web.HttpUtility]::UrlEncode($keyword) 

  # Webページを操作
  $response = Invoke-WebRequest2 $url 
  $html = $response.DocumentNode
  $elements = $html.SelectNodes("//table/tbody/tr")

  $address = @()
  for ($i = 0; $i -lt $elements.Count; $i++) {
    if ($elements[$i].ChildNodes.Count -eq 1) {
      $yomi = $elements[$i].InnerText
      $i++
      $name = $elements[$i].SelectNodes("(td)[1]").InnerText
      $tel = 
      switch ($elements[$i].SelectNodes("td/script").InnerText -match "[\d-]+") {
        $true { $Matches[0] }
        $false { $null }
      }
      $org = $elements[$i].SelectNodes("(td)[3]").InnerText
      $i++
      $tds = $elements[$i].SelectNodes("td")
      if ($tds.Count -le 4) {
        $group = $tds[2].InnerText
        $i++
      }
      $mail = $elements[$i].SelectNodes("(td)[4]").InnerText
      $pos = $elements[$i].SelectNodes("(td)[5]").InnerText

      $address += [ordered]@{シメイ = $yomi; 氏名 = $name; 連絡先 = $tel; 所属 = $org; グループ = $group; メール = $mail; 役職 = $pos }
    }
  }
  return $address
}

function InputKeyword() {
  # Windows FormsとDrawingアセンブリをロード
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  # 1. フォーム（ウィンドウ）の作成
  $form = New-Object System.Windows.Forms.Form
  $form.Text = "キーワード検索"
  # ★レイアウトに合わせてウィンドウサイズを調整
  $form.Size = New-Object System.Drawing.Size(480, 280) 
  $form.StartPosition = "CenterScreen"
  $form.FormBorderStyle = 'FixedDialog' # ウィンドウサイズの変更を禁止
  $form.MaximizeBox = $false
  $form.MinimizeBox = $false

  # --- ★ここからフォント設定 ---
  # 2. フォントを2種類定義する
  # (a) ラベルやボタン用の基本フォント (12pt)
  $baseFont = New-Object System.Drawing.Font("Meiryo UI", 12) 
  # (b) キーワード入力用の大きいフォント (24pt)
  $keywordFont = New-Object System.Drawing.Font("Meiryo UI", 24)
  # --- ★ここまでフォント設定 ---


  # 3. ラベルの作成
  $label = New-Object System.Windows.Forms.Label
  $label.Location = New-Object System.Drawing.Point(20, 20)
  $label.Size = New-Object System.Drawing.Size(420, 30)
  $label.Text = "検索キーワードを入力してください："
  $label.Font = $baseFont # ★基本フォント(12pt)を適用
  $form.Controls.Add($label)

  # 4. テキストボックス（キーワード入力欄）の作成
  $textBox = New-Object System.Windows.Forms.TextBox
  $textBox.Location = New-Object System.Drawing.Point(20, 60) # ★位置調整
  # ★フォントサイズに合わせて高さを十分に確保
  $textBox.Size = New-Object System.Drawing.Size(420, 45) 
  $textBox.Font = $keywordFont # ★キーワード用フォント(24pt)を適用
  $form.Controls.Add($textBox)

  # 5. ボタンの作成と配置
  $buttonY = 170 # ボタンを配置するY座標を統一

  # 5a. OKボタン
  $okButton = New-Object System.Windows.Forms.Button
  $okButton.Location = New-Object System.Drawing.Point(120, $buttonY)
  $okButton.Size = New-Object System.Drawing.Size(100, 40)
  $okButton.Text = "検索"
  $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $okButton.Font = $baseFont # ★基本フォント(12pt)を適用
  $form.AcceptButton = $okButton # EnterキーでOKボタンが押されるように設定
  $form.Controls.Add($okButton)

  # 5b. キャンセルボタン
  $cancelButton = New-Object System.Windows.Forms.Button
  $cancelButton.Location = New-Object System.Drawing.Point(240, $buttonY)
  $cancelButton.Size = New-Object System.Drawing.Size(120, 40)
  $cancelButton.Text = "キャンセル"
  $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $cancelButton.Font = $baseFont # ★基本フォント(12pt)を適用
  $form.CancelButton = $cancelButton # Escキーでキャンセルできるように設定
  $form.Controls.Add($cancelButton)

  # 6. フォームが読み込まれた時にテキストボックスにフォーカスを当てる
  $form.Add_Shown({ $form.ActiveControl = $textBox })

  # 7. フォームを表示し、ユーザーの操作を待つ
  $result = $form.ShowDialog()

  # 8. 結果の処理
  if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    # テキストボックスに入力された内容を取得
    $keyword = $textBox.Text
    if ([string]::IsNullOrWhiteSpace($keyword)) {
      Write-Host "キーワードが入力されていません。"
    }
    else {
      Write-Host "入力されたキーワード: $keyword"
      # ここに、取得したキーワードを使って実際の検索処理などを記述します
    }
  }
  else {
    Write-Host "キャンセルされました。"
  }

  # 9. フォームのリソースを解放
  $form.Dispose()
  return $keyword

}




if ("" -eq $keyword) {
  $keyword = InputKeyword
}

$address = getAddress($keyword) 
$json = $address | ConvertTo-JSON -Compress 
ConvertFrom-Json $json | Format-Table

Pause

#if (-not ($null -eq $address)) {
#  $json = $address | ConvertTo-JSON -Compress 
#  ConvertFrom-Json $json | Format-Table
#}
