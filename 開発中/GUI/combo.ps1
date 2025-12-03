Add-Type -AssemblyName PresentationFramework

# ウィンドウ作成
$window = New-Object System.Windows.Window
$window.Title = "Recommended ComboBox Implementation"
$window.Width = 400
$window.Height = 200

# コンボボックス作成
$comboBox = New-Object System.Windows.Controls.ComboBox
$comboBox.IsEditable = $true
$comboBox.Margin = "20"
$comboBox.ItemsSource = @("Apple", "Banana", "Cherry")

# Loaded後に内部TextBoxを取得してイベント追加
$comboBox.Add_Loaded({
        $comboBox.ApplyTemplate()
        $editable = $comboBox.Template.FindName("PART_EditableTextBox", $comboBox)

        if ($editable) {
            $editable.Add_KeyDown({
                    param($sender)   # sender は TextBox
                    $eventArgs = $_  # KeyEventArgs を退避

                    Write-Host "=== KeyDown Event Fired ==="
                    Write-Host "sender:" $sender.GetType().FullName
                    Write-Host "eventArgs:" $eventArgs.GetType().FullName
                    Write-Host "comboBox:" $comboBox.GetType().FullName

                    switch ($eventArgs.Key) {
                        "Down" {
                            if ($comboBox.Items.Count -gt 0) {
                                $comboBox.IsDropDownOpen = $true
                                $comboBox.Focus()
                                $comboBox.SelectedIndex = 0
                                $eventArgs.Handled = $true
                            }
                        }
                        "Tab" {
                            if ($comboBox.IsDropDownOpen -and $comboBox.SelectedItem) {
                                $comboBox.Text = $comboBox.SelectedItem
                                $comboBox.IsDropDownOpen = $false
                                $eventArgs.Handled = $true
                            }
                        }
                        "Return" {
                            $comboBox.IsDropDownOpen = $false
                            $eventArgs.Handled = $true
                            Write-Host "Enter pressed → DropDown closed"
                        }
                    }
                })        
        }
    })

# ウィンドウに配置
$window.Content = $comboBox
$window.ShowDialog() | Out-Null