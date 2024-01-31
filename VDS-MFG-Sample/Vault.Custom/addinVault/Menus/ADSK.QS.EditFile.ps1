
$vaultContext.ForceRefresh = $true
$fileId=$vaultContext.CurrentSelectionSet[0].Id
$dialog = $dsCommands.GetEditDialog($fileId)

#override the default dialog file assigned
$xamlFile = New-Object CreateObject.WPF.XamlFile "ADSK.QS.File.xaml", "C:\ProgramData\Autodesk\Vault 2025\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.File.xaml"
$dialog.XamlFile = $xamlFile

$dialog.Execute()

