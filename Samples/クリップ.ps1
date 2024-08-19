$msg =Get-Clipboard -Format Text

$wsobj = new-object -comobject wscript.shell
$result = $wsobj.popup($msg)

