$vaultContext.ForceRefresh = $true
$id=$vaultContext.CurrentSelectionSet[0].Id

$dialog = $dsCommands.GetEditCustomObjectDialog($id) #loads the default. 

#override the default dialog file assigned
$xamlFile = New-Object CreateObject.WPF.XamlFile "ADSK.QS.CustomObject.xaml", "C:\ProgramData\Autodesk\Vault 2025\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.CustomObject.xaml"
$dialog.XamlFile = $xamlFile

$result = $dialog.Execute()
#$dsDiag.Trace($result)