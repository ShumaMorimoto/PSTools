function Get-History {
    param([System.Windows.Controls.ComboBox]$cb, [string]$Keyword)
    $cb.Tag.History | Where-Object { $_.Keyword -eq $Keyword }
}
