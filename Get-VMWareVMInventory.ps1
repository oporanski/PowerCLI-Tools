<#
function Create-Exel()
{
    $Excel = New-Object -ComObject "Excel.Application" 
    $XLSXDoc = "Path of Excel File.xlsx" 
    $SheetName = "Sheet1" 
    $Workbook = $Excel.workbooks.open($XLSXDoc) 
    $Sheet = $Workbook.Worksheets.Item($SheetName) 
    $WriteData = $Excel.WorkSheets.Item($SheetName) 
    $RowCount = ($Sheet.usedRange.rows).count 
    $Excel.Visible = $true 
    $RowCount 

}
#>

param (
    [bool]$doDataStoreTotals = $false, 
    [bool]$dovCenterTotals = $false, 
    [bool]$dovCenterDetails = $true, 

	[string]$Folder = "", 
    [string]$vCenterServer = "vc.lab.local",

    [bool]$SaveReports = $true,
    [string]$SavePath = "C:\Temp",
    [string]$SendUNC ="\\servername\folder",
    [string]$reportVCD = "vCenterDetails.csv",
    [string]$reportVCT = "vCenterTotals.csv",
    [string]$reportDST = "DataStoreTotals.csv"
 )


###########################################################
####   DEBUG
$DEBUG = $true

function CleanReportFiles()
{
    if(Test-Path "$SavePath\$reportVCD")
    {
        Remove-Item "$SavePath\$reportVCD"
    }
    if(Test-Path "$SavePath\$reportVCT")
    {
        Remove-Item "$SavePath\$reportVCT"
    }
    if(Test-Path "$SavePath\$reportDST")
    {
        Remove-Item "$SavePath\$reportDST"
    }
    
    SaveToFile "vCenterName, DataCenter, Cluster, HAEnabled, DrsEnabled, ESXiCount, VMOn, VMOff, Templates`r`n" $reportVCT
    SaveToFile "vCenterName, DataCenter, Cluster, ESXi, DataStore, Type, Status, CapacityGB, FreeGB, UsedGB, SnapshotGB`r`n" $reportDST
    SaveToFile "vCenter, DataCenter, Cluster, ESXi, VMName, PowerState, NumberOfCpu's, MemoryGB, DatastoreNames, DatastoreTypes, UsedSpaceGB, ProvisionedSpaceGB, ToolsStatus, ToolsVersion, OSName, IPAddress, DNSName, DriveInfo`r`n" $reportVCD
}


function SaveToFile($log, $fileName)
{
    if($SaveReports -eq $true)
    {
        $log | Out-File  -FilePath $SavePath\$fileName -Encoding utf8 -Append
    }
}


function MoveToSharedStorage()
{
    #Copy reportsto shared storage
    if($SaveReports -eq $true -and $SendUNC -ne "")
    {
        if(Test-Path "$SavePath\$reportVCD")
        {
            Copy-Item "$SavePath\$reportVCD" $SendUNC
        }
        if(Test-Path "$SavePath\$reportVCT")
        {
            Copy-Item "$SavePath\$reportVCT" $SendUNC
        }
        if(Test-Path "$SavePath\$reportDST")
        {
            Copy-Item "$SavePath\$reportDST" $SendUNC
        }
    }
}

function Get-DataStoreTotals($vCenterName)
{
    if ($Folder -ne "")
    {
        $dcs = Get-Datacenter -Location $Folder
    }
    else 
    {
        $dcs = Get-Datacenter
    }

    foreach ($dc in $dcs)
    { 

        $clus = Get-Cluster -Location $dc
        foreach ($clu in $clus)
        {
            $esx = Get-VMHost -Location $clu
            $vms = Get-VM -Location $clu
            
            foreach ($esxHost in $esx)
            {
                $datastores = Get-Datastore -VMHost $esxHost            
                # Handle all datastores
                foreach($ds in $datastores)
                {
                    $freeSpace = [math]::Round($ds.CapacityGB, 2)
                    $capacity = [math]::Round( $ds.FreeSpaceGB, 2)
                    $usedSpace = [math]::Round(($ds.CapacityGB - $ds.FreeSpaceGB), 2)
                    $status = if($ds.Accessible){"Up"}else{"Down"}
                    $type = $ds.Type

                    $snapSpace = 0
                    $vmList = Get-VM -Datastore $ds
                    if ($vmList.Count -gt 0)
                    {
                        $snap = Get-Snapshot -VM $vmList
                        foreach ($s in $snap)
                        {
                            $snapSpace += $s.SizeGB
                        }
                    }
                    $snapSpace = [math]::Round($snapSpace, 2)

                    if($DEBUG)
                    {
                        Write-Host $vCenterName"," $dc.Name"," $clu.Name"," $esxHost.Name"," $ds.Name"," $type "," $status "," $capacity", " $freeSpace", "  $usedSpace", " $snapSpace

                    }
                    $l = $vCenterName + ", " + $dc.Name + ", " + $clu.Name + ", " + $esxHost.Name + ", " + $ds.Name + ", " + $type + ", " + $status + ", " + $capacity + ", " + $freeSpace+ ", " + $usedSpace+ ", " + $snapSpace
                    SaveToFile $l $reportDST
                }
            }

        }
    }
}

function Get-vCenterTotals($vCenterName)
{
    if ($Folder -ne "")
    {
        $dcs = Get-Datacenter -Location $Folder
    }
    else 
    {
        $dcs = Get-Datacenter
    }

    foreach ($dc in $dcs)
    { 
        $clus = Get-Cluster -Location $dc
        foreach ($clu in $clus)
        {
            $vms = Get-VM -Location $clu
            $vmPON = 0
            $vmPOFF = 0
            foreach ($vm in $vms)
            {
                if ($vm.PowerState -eq "PoweredOn")
                {
                    $vmPOn++ 
                }
                else 
                {
                    $vmPOff++
                }
            }
            $hostsESXi = Get-VMHost -Location $clu

            $templates = 0
            foreach ($h in $hostsESXi)
            {
                 $c = Get-Template -Location $h
                 $templates += $c.Count
            }

            if($DEBUG)
            {
                Write-Host $vCenterName"," $dc.Name"," $clu.Name"," $clu.HAEnabled"," $clu.DrsEnabled"," $hostsESXi.Count"," $vmPOn"," $vmPOff"," $templates
            }

            $l = $vCenterName +", " +$dc.Name +", " +$clu.Name +", " +$clu.HAEnabled +", " +$clu.DrsEnabled +", " +$hostsESXi.Count +", " + $vmPOn +", " + $vmPOff + $templates
            SaveToFile $l $reportVCT
        }
    }
}

function Get-vCenterDetails($vCenterName) 
{
    if ($Folder -ne "")
    {
        $dcs = Get-Datacenter -Location $Folder
    }
    else 
    {
        $dcs = Get-Datacenter
    }

    foreach ($dc in $dcs)
    {
        if($DEBUG) {
            Write-Host "Checking DC:" $dc.Name
        }
        $vms = Get-VM -Location $dc
        foreach ($vm in $vms)
        {
            if($DEBUG) {
                Write-Host "Checking VM:" $vm.Name
            }
            #get vm cluster 
            $cluster = Get-Cluster -VM $vm.Name
            #get vm datastores
            $vmds = Get-Datastore -VM $vm.Name 
            #get vm views
            $vmv = $vm | Get-View 
            
            $UsedSpace = [math]::Round(($vmv.Storage.PerDatastoreUsage.Committed/1024/1024/1024), 2)
            
            $ProvisionedSpace = [math]::Round((($vmv.Storage.PerDatastoreUsage.Committed+$vmv.Storage.PerDatastoreUsage.Uncommitted)/1024/1024/1024), 2)

            $tollsStatus = $vm.ExtensionData.Guest.ToolsStatus
            $toolsVer = $vm.ExtensionData.Guest.ToolsVersion

            #get vm guest os
            if ($vm.PowerState -eq "PoweredOn")
            {

                $vmg = Get-VMGuest -VM $vm.Name
                #$OSInfo = Get-VMGuest -VM $VirtualMachineName 
                $OSName =  $vmg.OSFullName 
                $OSIPAddress = $vmg.IPAddress 
                $VMDisks = $vmg.Disks
                $DNSName = $vmg.HostName
                #Calculating Disks Information 
                $diskcount = $VMDisks.Count -1 
                $DriveInfo = @() 
                For ($I=0; $I -le $diskcount; $I++) 
                { 
                    $DriveUsedSpace = [math]::Round($VMDisks[$I].FreeSpaceGB, 2)  
                    $DriveCapacity = [math]::Round($VMDisks[$I].CapacityGB, 2)
                    $DrivePath = $VMDisks[$I].Path 
                    $DriveInfo += $DrivePath + " Used Space Is " + $DriveUsedSpace+" Capacity Is "+$DriveCapacity 
                    $DriveInfo += "; " 
                } 
                 
            }

            if($DEBUG) {
                Write-Host $vCenterName"," $dc.Name"," $cluster"," $vm.Host"," $vm.Name"," $vm.PowerState"," $vm.NumCpu"," $vm.MemoryGB","`
                        $vmds.Name"," $vmds.Type"," $UsedSpace"," $ProvisionedSpace ","`
                        $tollsStatus"," $toolsVer"," $OSName"," $OSIPAddress"," $DNSName"," $DriveInfo
            }


            $l =  $vCenterName + ", " + $dc.Name + ", " + $cluster + "," + $vm.Host + ", " + $vm.Name + ", " + $vm.PowerState + ", " + $vm.NumCpu + ", " + $vm.MemoryGB + ", " + `
                        $vmds.Name + ", " + $vmds.Type + ", " + $UsedSpace  + ", " + $ProvisionedSpace + ", " + `
                        $tollsStatus + ", " + $toolsVer + ", " + $OSName + ", " + $OSIPAddress + ", " + $DNSName + ", " + $DriveInfo

            SaveToFile $l $reportVCD
        }

    }
}


### MAIN ###
if($Folder -ne "" -and $vCenterServer -eq "")
{
    Write-Host "You must specify both Folder and vCenterServer parameters"
    return
}

#Add-PSSnapin VMware.VimAutomation.Core
#Add-PSSnapin VMware.VumAutomation

#$adminCred = Get-Credential 
$site_list = @("vc01.lab.local", "vc02.lab.local")
$result = @()

CleanReportFiles

foreach ($site in $site_list) 
{
	$vcenter = "vc01.lab.local" 

	Write-Verbose "Connecting vCenter server $vcenter..."		
	#!!!!!!!!!!!TEST!!!!!!!!
    #Connect-VIServer -Server $vcenter -Credential $adminCred | Out-Null
	Connect-VIServer -Server $vcenter | Out-Null	
	Write-Verbose "Connected to $vcenter."
    
    if($dovCenterTotals)
    {
        Get-vCenterTotals $vcenter
    }
    if($doDataStoreTotals)
    {	
        Get-DataStoreTotals $vcenter
    }
    if($dovCenterDetails)
    {
        Get-vCenterDetails $vcenter
    }

	Disconnect-VIServer -Force -Confirm:$false | Out-Null
	Write-Verbose "Disconnected from $vcenter."
}

MoveToSharedStorage