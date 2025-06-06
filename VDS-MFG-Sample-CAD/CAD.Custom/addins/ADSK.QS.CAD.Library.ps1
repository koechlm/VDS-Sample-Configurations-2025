﻿# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


# retrieve property value given by displayname from folder (ID)
# don't use repeatetly for multiple properties and use the mGetAllFolderProperties method instead
function mGetFolderPropValue ([Int64] $mFldID, [STRING] $mDispName) {
	$PropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FLDR")
	$propDefIds = @()
	$PropDefs | ForEach-Object {
		$propDefIds += $_.Id
	} 
	$mPropDef = $propDefs | Where-Object { $_.DispName -eq $mDispName }
	$mEntIDs = @()
	$mEntIDs += $mFldID
	$mPropDefIDs = @()
	$mPropDefIDs += $mPropDef.Id
	$mProp = $vault.PropertyService.GetProperties("FLDR", $mEntIDs, $mPropDefIDs)
	$mProp | Where-Object { $mPropVal = $_.Val }
	Return $mPropVal
}

# read all properties for a single folder
# returns a name/value map (dictionary) using the UDP's displayname as the key
function mGetAllFolderProperties ([long] $FldID)
{
	$mResult = @{}
	if (!$global:mFldrPropDefs) {
		$global:mFldrPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FLDR")
	}
	$propDefIds = @()
	$mFldrPropDefs | ForEach-Object {
		$propDefIds += $_.Id
	}	
	$mEntIDs = @()
	$mEntIDs += $mFldID
	$mPropertyInstances = $vault.PropertyService.GetProperties("FLDR", $mEntIDs, $propDefIds)	
	Foreach($mPropInst in $mPropertyInstances){		
		$Name = ($mFldrPropDefs | Where-Object {$_.Id -eq $mPropInst.PropDefId}).DispName
		$mResult.Add($Name, $mPropInst.Val)
	}	
	Return $mResult
}

# read a parent folder's (Id) properties and copy values to the current file's properties listed in the mapping table
function mInheritProperties ($Id, $MappingTable) {
	#read the source entity's properties
	$mFldProps = @{}
	$mFldProps += mGetAllFolderProperties($Id)
	
	#iterate the target properties and retrieve the value of the mapped source 
	$MappingTable.GetEnumerator() | ForEach-Object {
		$Prop[$_.Name].Value = $mFldProps[$_.Value]
	}	
}

#Get parent project folder object
function mGetNewFileParentFldrByCat ([string] $Category) {
	#get the Vault path of Inventors working folder
	$mappedRootPath = $Prop["_VaultVirtualPath"].Value + $Prop["_WorkspacePath"].Value
	$mappedRootPath = $mappedRootPath -replace "\\", "/" -replace "//", "/"
	if ($mappedRootPath -eq '') {
		$mappedRootPath = '$/'
	}
	#$dsDiag.Trace("mapped root: $($mappedRootPath)")
	$mWfVault = $mappedRootPath
					
	#get local path of vault workspace path for Inventor
	If ($dsWindow.Name -eq "InventorWindow") {
		$mCAxRoot = $mappedRootPath.Split("/")[1]
	}
	if ($dsWindow.Name -eq "AutoCADWindow") {
		$mCAxRoot = ""
	}

	if ($vault.DocumentService.GetEnforceWorkingFolder() -eq "true") {
		$mWF = $vault.DocumentService.GetRequiredWorkingFolderLocation()
	}
	else {
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("Iterating parent folders expects enforced Vault settings for Working Folder & IPJ!" , "Inventor VDS Client")
		return
	}

	try {
		#$dsDiag.Trace("mWF: $mWF")
		$mWFCAD = $mWF + $mCAxRoot
		#avoid for temporary files
		if (-not $Prop["_FilePath"].Value -like $mWFCAD + "*") {
			$Prop[$mCadFileTargetPropertyName].Value = ""
			return
		}
		#merge the local path and relative target path of new file in vault
		$mPath = $Prop["_FilePath"].Value.Replace($mWFCAD, "")
		$mPath = $mWfVault + $mPath
		$mPath = $mPath.Replace(".\", "")
		$mPath = $mPath.Replace("\", "/")
		$mPath = $mPath.Replace("//", "/")
		$mFld = $vault.DocumentService.GetFolderByPath($mPath)
		#the loop to get the next parent project category folder; skip if you don't look for projects
		IF ($mFld.Cat.CatName -eq $UIString[$Category]) { $mFldrFound = $true }
		ElseIf ($mPath -ne "$/") {
			Do {
				$mParID = $mFld.ParID
				$mFld = $vault.DocumentService.GetFolderByID($mParID)
				IF ($mFld.Cat.CatName -eq $UIString[$Category]) { $mFldrFound = $true }
			} 
			Until (($mFld.Cat.CatName -eq $UIString[$Category]) -or ($mFld.FullName -eq "$"))
		}	
	}
	catch { 
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("Failed retreiving the target Vault folder's path of this new file" , "Inventor VDS Client")
	}			

	If ($mFldrFound -eq $true) {
		return $mFld
	}
	Else {
		return $null
	}
}


# VDS Dialogs and Tabs share property name translations $Prop[_XLTN_*] according DSLanguage.xml override or default powerShell UI culture;
# VDS MenuCommand scripts don't read as a default; call this function in case $UIString[] key value pairs are needed
function mGetUIOverride {
	# check language override settings of VDS
	[xml]$mDSLangFile = Get-Content "C:\ProgramData\Autodesk\Vault 2025\Extensions\DataStandard\Vault\DSLanguages.xml"
	$mUICodes = $mDSLangFile.SelectNodes("/DSLanguages/Language_Code")
	$mLCode = @{}
	Foreach ($xmlAttr in $mUICodes) {
		$mKey = $xmlAttr.ID
		$mValue = $xmlAttr.InnerXML
		$mLCode.Add($mKey, $mValue)
	}
	return $mLCode
}

# client and server (database) languages may differ; read the enforced language code to capture multilanguage labels
function mGetDBOverride {
	# check language override settings of VDS
	[xml]$mDSLangFile = Get-Content "C:\ProgramData\Autodesk\Vault 2025\Extensions\DataStandard\Vault\DSLanguages.xml"
	$mUICodes = $mDSLangFile.SelectNodes("/DSLanguages/Language_Code")
	$mLCode = @{}
	Foreach ($xmlAttr in $mUICodes) {
		$mKey = $xmlAttr.ID
		$mValue = $xmlAttr.InnerXML
		$mLCode.Add($mKey, $mValue)
	}
	return $mLCode
}

# VDS Dialogs and Tabs share property name translations $Prop[_XLTN_*] according DSLanguage.xml override or default powerShell UI culture;
# VDS MenuCommand scripts don't read as a default; call this function in case $PropertyTranslations[] key value pairs are needed
function mGetPropTranslations {
	# check language override settings of VDS
	[xml]$mDSLangFile = Get-Content "C:\ProgramData\Autodesk\Vault 2025\Extensions\DataStandard\Vault\DSLanguages.xml"
	$mUICodes = $mDSLangFile.SelectNodes("/DSLanguages/Language_Code")
	$mLCode = @{}
	Foreach ($xmlAttr in $mUICodes) {
		$mKey = $xmlAttr.ID
		$mValue = $xmlAttr.InnerXML
		$mLCode.Add($mKey, $mValue)
	}
	#If override exists, apply it, else continue with $PSUICulture
	If ($mLCode["DB"]) {
		$mVdsDb = $mLCode["DB"]
	} 
	Else {
		$mVdsDb = $PSUICulture
	}
	[xml]$mPrpTrnsltnFile = get-content ("C:\ProgramData\Autodesk\Vault 2025\Extensions\DataStandard\" + $mVdsDb + "\PropertyTranslations.xml")
	$mPrpTrnsltns = @{}
	$xmlPrpTrnsltns = $mPrpTrnsltnFile.SelectNodes("/PropertyTranslations/PropertyTranslation")
	Foreach ($xmlAttr in $xmlPrpTrnsltns) {
		$mKey = $xmlAttr.Name
		$mValue = $xmlAttr.InnerXML
		$mPrpTrnsltns.Add($mKey, $mValue)
	}
	return $mPrpTrnsltns
}

# not all VDS powershell runspaces provide the multi-language labels $UIStrings
# call this function in case $UIStrings[] key value pairs are needed but not available
function mGetUIStrings {
	# check language override settings of VDS
	$mLCode = @{}
	$mLCode += mGetUIOverride
	#If override exists, apply it, else continue with $PSUICulture
	If ($mLCode["UI"]) {
		$mVdsUi = $mLCode["UI"]
	} 
	Else { $mVdsUi = $PSUICulture }
	[xml]$mUIStrFile = get-content ("C:\ProgramData\Autodesk\Vault 2025\Extensions\DataStandard\" + $mVdsUi + "\UIStrings.xml")
	$UIString = @{}
	$xmlUIStrs = $mUIStrFile.SelectNodes("/UIStrings/UIString")
	Foreach ($xmlAttr in $xmlUIStrs) {
		$mKey = $xmlAttr.ID
		$mValue = $xmlAttr.InnerXML
		try{
			$UIString.Add($mKey, $mValue)
		}
		catch{
			[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("Failed adding this UIString $mKey; please check that the key does not exist already." , "Vault VDS Client")
		}
	}
	return $UIString
}