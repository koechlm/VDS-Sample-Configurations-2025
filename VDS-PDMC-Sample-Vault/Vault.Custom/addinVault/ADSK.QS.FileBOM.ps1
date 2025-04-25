class mBomRow {
	[int32] $Position
	[string] $PartNumber
	[string] $ComponentType
	[float] $Quantity
	[string] $Name
	[byte[]] $Thumbnail
	[string] $Title
	[string] $Description
	[string] $Material
}

class mBom {
	[mBomRow[]] $BOMItems	
}

function mGetMdlStates($fileID) {
		
	$global:mFileBOM = $vault.DocumentService.GetBOMByFileId($fileID)
	#$dsDiag.Inspect("mFileBOM")
	$MsArray = @()
	$MsArray += $mFileBom.CompArray | Where-Object { $_.XRefId -eq -1 -and ($_.UniqueId -like "MS:*" -or $_.Name -contains "[*]") } # model state BOMs are internal component BOMs
	
	if ($MsArray.Count -gt 1) {
		$mMdlStates = @{}
		$MsArray | ForEach-Object { 
			$mName = ""
			# back port from 2026 not applicable, as 2025 File BOM does not have the primary state name
			# if ($_.Name -like "[*]") {
			# 	$mName = "[Primary]"
			# }
			if ($_.Name -like "* (*)") {
				#get the model state name
				$mName = $_.Name.Split("(")[1]
				$mName = $mName.Substring(0, $mName.Length - 1)					
			}	#add the primary state name		
			try {
				$mMdlStates.Add($mName, $_.Id)		
			}
			catch {
				<#Do this if a terminating exception happens#>
			}	
		}
		#add the primary state name for 2025 compatibility
		$mMdlStates.Add("[Primary]", 0)
		#sort the model states by name
		$mMdlStates = $mMdlStates.GetEnumerator() | Sort-Object Name		
		$dsWindow.FindName("cmbModelStates").ItemsSource = $mMdlStates
		$dsWindow.FindName("cmbModelStates").SelectedIndex = 0
		$dsWindow.FindName("cmbModelStates").IsEnabled = $true
	}
	else {
		$dsWindow.FindName("cmbModelStates").IsEnabled = $false
		$dsWindow.FindName("cmbModelStates").SelectedIndex = -1
		$dsWindow.FindName("cmbModelStates").ItemsSource = $null		
	}

	return $MsArray
}

function GetFileBOM($fileID, $BomCompId) {
	#Get Thumbnail PropertyDefinition 
	$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId('FILE')
	$thumbnailPropDef = $propDefs | Where-Object { $_.SysName -eq 'Thumbnail' }

	if ($null -eq $Global:mFileBOM) {
		$global:mFileBom = $vault.DocumentService.GetBOMByFileId($fileID)
	}	

	$cldIds = @()
	$mFileBom.InstArray | Where-Object { $_.ParId -eq $BomCompId } | ForEach-Object { 
		#[autodesk.Connectivity.WebServices.BOMInst]$mBomInst = $_
		#$dsDiag.Inspect("mBomInst")
		$CldId = $_.CldId
		$comp = $mFileBom.CompArray | Where-Object { $_.Id -eq $CldId }
		#$dsDiag.Inspect("comp")		
		if ($comp.XRefId -ne -1) {
			$cldIds += $comp.XRefId
		}
	}
	#$dsDiag.Inspect("cldIds")

	$bomItems = @()
	if ($cldIds.Count -gt 0) {
		#the file contains BOM information, so continue
		$CldBoms = $vault.DocumentService.GetBOMByFileIds($cldIds)
		$schm = $mFileBom.SchmArray | Where-Object { $_.SchmTyp -eq "Structured" -and $_.RootCompId -eq $BomCompId }
		$cldBomCounter = 0
		#$dsDiag.Inspect("schm")
		$mFileBom.InstArray | Where-Object { $_.ParId -eq $BomCompId } | ForEach-Object {
			#[autodesk.Connectivity.WebServices.BOMInst]$mBomInst = $_
			#$dsDiag.Inspect("mBomInst")
			$bomItem = New-Object mBomRow
			$CldId = $_.CldId #$BomCompId
			if ($_.QuantOverde -eq -1) {
				$bomItem.Quantity = $_.Quant
			}
			else {
				$bomItem.Quantity = $_.QuantOverde
			}
			$comp = $mFileBom.CompArray | Where-Object { $_.Id -eq $CldId }
			#$dsDiag.Inspect("comp")
			$occur = $mFileBom.SchmOccArray | Where-Object { $_.SchmId -eq $schm.Id -and $_.CompId -eq $CldId }
			$bomItem.Position = $occur.DtlId
			#$dsDiag.Inspect("occur")
			if ($comp.XRefId -eq -1) {
				$cldBom = $mFileBom
			}
			else {
				$cldBom = $CldBoms[$cldBomCounter++]
			}
			$UniqueId = $comp.UniqueId
			#find component in current file bom only
			$cldComp = $cldBom.CompArray | Where-Object { $_.UniqueId -eq $UniqueId -and $_.XRefId -eq -1 } #| Select-Object -First 1
			#$dsDiag.Inspect("cldComp")
			if (-not $cldComp) {
				$cldComp = $cldBom.CompArray[0]
			}
			$bomItem.Name = $cldComp.Name
			$bomItem.ComponentType = $cldComp.CompTyp
			$cldCompAttrArray = $cldBom.CompAttrArray | Where-Object { $_.CompId -eq $cldComp.Id }
			if ($cldCompAttrArray.Count -eq 0) {
				$cldCompAttrArray = $cldBom.CompAttrArray
			}
			$PropPartNumber = $cldBom.PropArray | Where-Object { $_.dispName -eq "Part Number" }
			$prop = ($cldCompAttrArray | Where-Object { $_.PropId -eq $PropPartNumber.Id }) | Select-Object -First 1
			$bomItem.PartNumber = $prop.Val
			$bomItems += $bomItem
			#$dsDiag.Inspect("prop")
			#add Inventor default BOM columns
			$thumbnailProp = $vault.PropertyService.GetProperties('FILE', @($cldIds[$cldBomCounter - 1]), @($thumbnailPropDef.Id))[0]
			$bomItem.Thumbnail = $thumbnailProp.Val
			$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Title" }
			$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id } | Select-Object -First 1
			$bomItem.Title = $prop.Val
			$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Description" }
			$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id } | Select-Object -First 1
			$bomItem.Description = $prop.Val
			$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Material" }
			$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id } | Select-Object -First 1
			$bomItem.Material = $prop.Val					
		}				
	}
	$global:mPrimaryBOM = New-Object mBom
	$global:mPrimaryBOM.BOMItems += $bomItems

	#sort the BOM items by position
	$bomItems = $bomItems | Sort-Object Position
	return $bomItems
}
	

function mGoToCadBomCompFile {
	$selectedBomRow = $dsWindow.FindName("bomList").SelectedItem
	[System.Reflection.Assembly]::LoadFrom('C:\Program Files\Autodesk\Autodesk Vault 2026 SDK\bin\x64\Autodesk.Connectivity.Explorer.ExtensibilityTools.dll')
	[Autodesk.Connectivity.Explorer.ExtensibilityTools.IExplorerUtil]$mExplorerUtil = [Autodesk.Connectivity.Explorer.ExtensibilityTools.ExplorerLoader]::GetExplorerUtil($VaultApplication)
		
	#search a file to navigate to. Note the search returns the first file found; ensure that part number is unique in the vault
	$mFile = mSearchFileByPartNumber($selectedBomRow.PartNumber)
	
	# convert the file to an IEntity file object
	[Autodesk.DataManagement.Client.Framework.Vault.Currency.Entities.FileIteration]$mFileIteration = New-Object Autodesk.DataManagement.Client.Framework.Vault.Currency.Entities.FileIteration($vaultconnection, $mFile)

	#navigate to the file in the vault explorer
	$mExplorerUtil.GoToEntity($mFileIteration)
}

function mGoToCadBomCompItem {
	$selectedBomRow = $dsWindow.FindName("bomList").SelectedItem
	[System.Reflection.Assembly]::LoadFrom('C:\Program Files\Autodesk\Autodesk Vault 2026 SDK\bin\x64\Autodesk.Connectivity.Explorer.ExtensibilityTools.dll')
	[Autodesk.Connectivity.Explorer.ExtensibilityTools.IExplorerUtil]$mExplorerUtil = [Autodesk.Connectivity.Explorer.ExtensibilityTools.ExplorerLoader]::GetExplorerUtil($VaultApplication)
		
	#search a file to navigate to. Note the search returns the first file found; ensure that part number is unique in the vault
	$mFile = mSearchFileByPartNumber($selectedBomRow.PartNumber)
	
	#get the first linked item from the file
	$mItem = $vault.ItemService.GetItemsByFileId($mFile.Id)[0]

	if ($null -ne $mItem) {
		# convert the item to an IEntity file object
		[Autodesk.DataManagement.Client.Framework.Vault.Currency.Entities.ItemRevision]$mItemRevision = New-Object Autodesk.DataManagement.Client.Framework.Vault.Currency.Entities.ItemRevision($vaultconnection, $mItem)
		
		#navigate to the item in the vault explorer
		$mExplorerUtil.GoToEntity($mItemRevision)
	}
}

function mSearchFileByPartNumber([String]$PartNumber) {
	$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
	$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
	$propDef = $propDefs | Where-Object { $_.SysName -eq "PartNumber" }
	$srchCond.PropDefId = $propDef.Id
	$srchCond.SrchOper = 3
	$srchCond.SrchTxt = $PartNumber
	$srchCond.PropTyp = [Autodesk.Connectivity.WebServices.PropertySearchType]::SingleProperty
	$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::Must

	$mSearchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
	$srchSort = New-Object Autodesk.Connectivity.WebServices.SrchSort
	#$srchSort
	$mBookmark = ""     
	$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.File]'

	while (($mSearchStatus.TotalHits -eq 0) -or ($mResultAll.Count -lt $mSearchStatus.TotalHits)) {
		$mResultPage = $vault.DocumentService.FindFilesBySearchConditions(@($srchCond), @($srchSort), @(($vault.DocumentService.GetFolderRoot()).Id), $true, $true, [ref]$mBookmark, [ref]$mSearchStatus)
		#check the indexing status; you might return a warning that the result bases on an incomplete index, or even return with a stop/error message, that we need to have a complete index first
		If ($mSearchStatus.IndxStatus -eq "IndexingComplete" -or $mSearchStatus -eq "IndexingContent") {
		}
		if ($mResultPage.Count -ne 0) {
			$mResultAll.AddRange($mResultPage)
		}
		else { break; }
			
		break; #limit the search result to the first result page; page scrolling not implemented in this snippet release
	}

	return $mResultAll[0]
}

# Function to handle the search button click event
function CadBomSearchButton_Click {
	# Get the search text from the TextBox
	$searchText = $dsWindow.FindName("txtCadBomSearch").Text

	# Call the FilterBOMList function to filter the BOM list based on the search text
	FilterBOMList -searchText $searchText

	# enable the clear button if the search filtered the list
	$dsWindow.FindName("btnCadBomClear").IsEnabled = $true
	# disable the Find button to avoid changing the search text while filtering
	$dsWindow.FindName("btnCadBomFind").IsEnabled = $false
}

# Function to handle the clear button click event
function CadBomClearButton_Click {
	# Clear the search text in the TextBox
	$dsWindow.FindName("txtCadBomSearch").Text = ""

	#reset the bom list to its original state if the search text is empty
	$dsWindow.FindName("bomList").ItemsSource = $global:currentBOMList

	#disable the clear button and enable the Find button
	$dsWindow.FindName("btnCadBomFind").IsEnabled = $true
	$dsWindow.FindName("btnCadBomClear").IsEnabled = $false

}

# Function to filter the BOM list based on a search string
function FilterBOMList {
	param (
		[string]$searchText
	)

	# Escape the '*' character in the search text
	$escapedSearchText = [regex]::Escape($searchText)
	
	# avoid to update the unfiltered list with a filtered one
	if ($null -eq $global:currentBOMList) {
		$global:currentBOMList = $dsWindow.FindName("bomList").ItemsSource
	}

	# Restrict the '*' character
	if ($searchText -match '\*') {
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowWarning("The '*' character is not allowed in the search.", "Invalid Input", "OK")
	}

	# Filter the BOM list by checking all properties of each mBomRow
	$global:filteredBOMList = New-Object mBom
	$global:filteredBOMList = $currentBOMList | Where-Object {
		$row = $_
		$row.PSObject.Properties.Value | ForEach-Object {
			if ($_ -match $escapedSearchText) {
				# If any property matches the search text, return true to include this row in the filtered list and enable the clear button
				$dsWindow.FindName("btnCadBomClear").IsEnabled = $true
				return $true
			}			
		}
		# If no properties matched, return false and disable the clear button
		$dsWindow.FindName("btnCadBomClear").IsEnabled = $false
		return $false
	}

	# Ensure the result is enumerable
	if ($filteredBOMList.Count -eq 1) {
		$filteredBOMList = @($filteredBOMList)
	}

	# Update the ItemsSource of the BOM list with the filtered results
	$dsWindow.FindName("bomList").ItemsSource = $filteredBOMList
}