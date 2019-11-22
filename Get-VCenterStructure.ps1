#Add-PSSnapin VMware.VimAutomation.Core
#Add-PSSnapin VMware.VumAutomation
########################################################################
### GLOBALS ###
#Change this if you want to change the report save path 
$reportPath = [Environment]::GetFolderPath("Desktop") + "\vCenterStructure.txt"

#do you want a verbose comments? 
$verbose = $true

#vcenter servers site list
$site_list = @("vc01.lab.local", "vc02.lab.local")

########################################################################
### Do Not Edit
$report = @()

function CleanReportFiles()
{
    if(Test-Path $reportPath)
    {
        Remove-Item $reportPath
    }
}


function SaveToFile($log, $fileName)
{
    $log | Out-File  -FilePath $fileName -Encoding utf8 -Append
}


function VVGetPath($InvObject){
    if($InvObject){
 
        $objectType = $InvObject.GetType().Name
        $objectBaseType = $InvObject.GetType().BaseType.Name
        if($objectType.Contains("DatastoreImpl")){
            Write-Error "Use the VVGetDataStorePath function to determine datastore paths."
            break
        }
        <#
        if(-not ($objectBaseType.Contains("InventoryItemImpl") -or $objectBaseType.Contains("FolderImpl") -or $objectBaseType.Contains("DatacenterImpl") -or $objectBaseType.Contains("VMHostImpl") -or $objectBaseType.Contains("ClusterImpl")) ){
            Write-Error ("The provided object is not an expected vSphere object type. Object type is " + $objectType)
            break
        }
        #>

        $path = ""
        # Recursively move up through the inventory hierarchy by parent or folder.
        if($InvObject.ParentId -and $InvObject.ParentId -ne $null){
            $path = VVGetPath(Get-Inventory -Id $InvObject.ParentId)
        } elseif ($InvObject.ParentFolderId -and $InvObject.ParentFolderId -ne $null){
            $path = VVGetPath(Get-Folder -Id $InvObject.ParentFolderId)
        }
 
        # Build the path, omitting the "Datacenters" folder at the root.
        if(-not $InvObject.isChildTypeDatacenter -or $InvObject.GetType().Name -ne "FolderWrapper"){ # Add object to the path.
            $path = $path + "/" + $InvObject.Name
        }
        $path
    }
}


CleanReportFiles

foreach ($site in $site_list) 
{
	$vcenter = $site 
	Connect-VIServer -Server $vcenter | Out-Null	
    if($verbose){
        Write-Host "Starting scan vCenter: " $vcenter
    }

    
    $clus = Get-Cluster -Server $vcenter

    foreach ($clu in $clus)
    {
        if($verbose){
            Write-Host "Determining path for cluster: " $clu
        }

        $path = VVGetPath $clu
        $report = $vcenter + $path
        SaveToFile $report $reportPath
    }
    
	Disconnect-VIServer -Server $vcenter -Force -Confirm:$false | Out-Null
	if($verbose){
        Write-host "Disconnected from $vcenter."
    }
}
	if($verbose){
        Write-host "FINISHED!"
    }

