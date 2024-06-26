function InitializeBreadCrumb()
{
	if ($Prop["_CreateMode"].Value)
    {
        $rootFolder = GetVaultRootFolder
        $root = New-Object PSObject -Property @{ Name = $rootFolder.Name; ID=$rootFolder.Id }		
	    $global:expandBreadCrumb = $false
        AddCombo -data $root
	    $paths = $Prop["_SuggestedVaultPath"].Value.Split('\',[System.StringSplitOptions]::RemoveEmptyEntries)
        for($i=0;$i -lt $paths.Count;$i++)
	    {
            $cmb = $dsWindow.FindName("cmbBreadCrumb_"+$i)
            if ($cmb -ne $null) { $cmb.SelectedValue = $paths[$i] }
        }
    }
}

function GetChildFolders($folder)
{
	$ret = @()
	$folders = $vault.DocumentService.GetFoldersByParentId($folder.ID, $false)
	if($folders -ne $null){
		foreach ($item in $folders) {
			if (-Not $item.Cloaked)
			{
				$f = New-Object PSObject -Property @{ Name = $item.Name; ID=$item.Id }	
				$ret += $f
			}
		}
	}
	if ($ret.Count -gt 0)
    {
	    $ret += New-Object PSObject -Property @{ Name = "."; ID=-1 }
    }
	return $ret
}

function GetFullPathFromBreadCrumb($breadCrumb)
{
	$path = ""
	foreach ($crumb in $breadCrumb.Children) {
		$path += $crumb.SelectedItem.Name+"\"
	}
	return $path
}

function OnSelectionChanged($sender)
{
	$breadCrumb = $dsWindow.FindName("BreadCrumb")
    $position = [int]($sender.Name.Split('_')[1]);
	$children = $breadCrumb.Children.Count - 1
    while($children -gt $position )
    {
        $cmb = $breadCrumb.Children[$children]
        $breadCrumb.UnregisterName($cmb.Name)
        $breadCrumb.Children.Remove($cmb)
		$children--
    }
	$path = GetFullPathFromBreadCrumb -breadCrumb $breadCrumb
	$Prop["Folder"].Value = $path
    AddCombo -data $sender.SelectedItem
}


function AddCombo($data)
{
	if ($data.Name -eq '.' -or $data.Id -eq -1)
    {
        return
    }
	$children = GetChildFolders -folder $data
	if($children -eq $null) { return }
	$breadCrumb = $dsWindow.FindName("BreadCrumb")
	$cmb = New-Object System.Windows.Controls.ComboBox
	$cmb.Name = "cmbBreadCrumb_" + $breadCrumb.Children.Count.ToString();
	$cmb.DisplayMemberPath = "Name"
	$cmb.SelectedValuePath = "Name"
	$cmb.ItemsSource = @($children)
	$cmb.IsDropDownOpen = $global:expandBreadCrumb
	$cmb.add_SelectionChanged({
		param($sender,$e)
		OnSelectionChanged -sender $sender
	});
    $breadCrumb.RegisterName($cmb.Name, $cmb)
    $breadCrumb.Children.Add($cmb)
}
