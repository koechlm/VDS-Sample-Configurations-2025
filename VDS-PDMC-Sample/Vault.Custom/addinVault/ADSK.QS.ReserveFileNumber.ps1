# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


function Reserve 
{
	#	$dsDiag.Trace(">> Start Reserve ...")
	try
	{
		$dsWindow.FindName("Range").Text = ""
		#retrieve inputs
		$NumschemeName = $dsWindow.FindName("NumSchms").SelectedValue
		$NumSchmType = $dsWindow.FindName("cmbNumType").Text
		
		$ns = $global:mNmSchm | Where-Object { $_.Name.Equals($NumschemeName) }
		$TotalNum = $dsWindow.FindName("TotalNum").Text

		If ($dsWindow.FindName("cmbNumType").Text -eq $UIString["ADSK-RSRVNUMBERS_LBL108"]){
			[System.Windows.MessageBoxResult]$result = [Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowWarning($UIString["ADSK-RSRVNUMBERS_MSG08"] + "`n" + "`n" + $UIString["ADSK-RSRVNUMBERS_MSG09"], "Vault VDS-PDMC-Sample - Reserve Numbers", "OkCancel")
			if ($result -ne 1){
				return
			}
		}

		#prepare numbering
		[string[]]$NumGenArgs = @()
		$mNumCtrl = $dsWindow.DataContext.NumSchemeCtrlViewModel
		#Filter Freetext and pre-defined list
		foreach ($mField in $mNumCtrl.NumSchmFields) 
			{
				IF (($mField.FieldTyp -eq "FreeText") -or ($mField.FieldTyp -eq "PreDefinedList"))
					{
						$NumGenArgs += $mField.Value
					}
			}
		if ($NumGenArgs.Count -eq 0) {$NumGenArgs = @("")}
		$nsIDs = @($ns.SchmID)
		#create the numbers in given quantity
		for ($i=1; $i -le $TotalNum; $i++)
			{
				switch ($NumSchmType) 
				{
					$UIString["ADSK-RSRVNUMBERS_LBL107"]
					{
						$num = $vault.DocumentService.GenerateFileNumber($ns.SchmID, $NumGenArgs)
					}

					$UIString["ADSK-RSRVNUMBERS_LBL108"]
					{
					
						#Get target item category Id
						$mEntityCategories = $vault.CategoryService.GetCategoriesByEntityClassId("ITEM", $true)
						$mEntCatId = ($mEntityCategories | Where-Object {$_.Name -eq "Document" }).ID

						#Create new item
						[Autodesk.Connectivity.WebServices.Item]$NewItem = $vault.ItemService.AddItemRevision($mEntCatId)
						$NewItem.Title = "Reserved Item Number"		

						#build item number input array
						[Autodesk.Connectivity.WebServices.ProductRestric]$mRstrct
						$mRestrictions = @($mRstrct)
						[Autodesk.Connectivity.WebServices.StringArray]$mFldInpt = new-object Autodesk.Connectivity.WebServices.StringArray				
						$mFldInpt.Items = $NumGenArgs
						[Autodesk.Connectivity.WebServices.StringArray[]]$mInputs =  new-object Autodesk.Connectivity.WebServices.StringArray
						$mInputs[0] = $mFldInpt

						if ($ns.IsDflt -eq $false)
						{
							$mNmbrs = @()
							$mNmbrs += $vault.ItemService.AddItemNumbers(@($NewItem.MasterId), @($ns.SchmID), $mInputs, [ref]$mRestrictions)
							$NewItem.ItemNum = $mNmbrs[0].ItemNum1
							$vault.ItemService.CommitItemNumbers(@($NewItem.MasterId), @($mNmbrs[0].ItemNum1))			
							$num = $mNmbrs[0].ItemNum1
						}
						else{
							$vault.ItemService.CommitItemNumbers(@($NewItem.MasterId), @($NewItem.ItemNum))
							$num = $NewItem.ItemNum
						}

						#update the equivalence value property to enable item re-use on matching numbers
						if (!$ItemPropDefs){
							$ItemPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("ITEM")
							$EqValDefId = $ItemPropDefs | Where-Object {$_.SysName -eq "EquivalenceValue"}
						}
						$propValues = New-Object Autodesk.Connectivity.WebServices.PropInstParamArray
						$propValues.Items = New-Object Autodesk.Connectivity.WebServices.PropInstParam[] 1
						$propValues.Items[0] = New-Object Autodesk.Connectivity.WebServices.PropInstParam -Property @{PropDefId = $EqValDefId.Id;Val = $num}
						$UpdatedItems = $vault.ItemService.UpdateItemProperties(@($NewItem.RevId), $propValues)
						$vault.ItemService.UpdateAndCommitItems($UpdatedItems)
					}

					$UIString["ADSK-RSRVNUMBERS_LBL109"]
					{
						$num = $vault.ChangeOrderService.GetChangeOrderNumberBySchemeId($ns.SchmID)
					}
				}

				$dsWindow.FindName("Range").Text = $dsWindow.FindName("Range").Text + $num + "`n"
			}

			[Windows.Forms.Clipboard]::SetText($dsWindow.FindName("Range").Text)

	} #end try
	catch 
	{
	  	$dsDiag.Trace("...Error during number reservation...")
	}

	#$dsDiag.Trace(" ...Reserve finished successfully<<")
}

function mGetNumType
{
	$mTypes = @($UIString["ADSK-RSRVNUMBERS_LBL107"], $UIString["ADSK-RSRVNUMBERS_LBL108"], $UIString["ADSK-RSRVNUMBERS_LBL109"])
	return $mTypes
}

function mGetNumSchms
{
	#$dsDiag.Trace(">> Reserver Numbers -> mGetNumSchms starts...")
	switch ($dsWindow.FindName("cmbNumType").SelectedValue) 
	{
			$UIString["ADSK-RSRVNUMBERS_LBL107"]{
				$global:mNmSchm = $vault.NumberingService.GetNumberingSchemes('FILE', 'Activated')
				$dsWindow.FindName("NumSchms").ItemsSource = $global:mNmSchm
				$dsWindow.FindName("NumSchms").SelectedIndex = 0
			}
			$UIString["ADSK-RSRVNUMBERS_LBL108"]{
				$global:mNmSchm = $vault.NumberingService.GetNumberingSchemes('ITEM', 'Activated')
				$dsWindow.FindName("NumSchms").ItemsSource = $global:mNmSchm
				$dsWindow.FindName("NumSchms").SelectedIndex = 0
			}
			$UIString["ADSK-RSRVNUMBERS_LBL109"]{
				$global:mNmSchm = $vault.NumberingService.GetNumberingSchemes('CO', 'Activated')
				$dsWindow.FindName("NumSchms").ItemsSource = $global:mNmSchm
				$dsWindow.FindName("NumSchms").SelectedIndex = 0
			}
	}
	#$dsDiag.Trace("<<...Reserve Numbers -> mGetNumSchms finished: '$($global:mNmSchm.Count)'")
}