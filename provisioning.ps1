# Find Thin/Thick Disks
# Identifies VMs and templates that are using thin-provisioned
# virtual disks.

param (
    [string]$server = "vc01.lab.local",
	[string]$entity = "",
    [switch]$SaveToFile,
    [string]$path = [Environment]::GetFolderPath("Desktop") + "\VMwareThickProvisionedDisks.txt"
 )

function do_clear_screen(){
    clear
    Write-Host "#### VMware Disk provisioning check ####"
    Write-Host
    Write-Host
}
 
do_clear_screen
Set-PowerCLIConfiguration -InvalidCertificateAction "Ignore" -Confirm:$false

$report = @()

Connect-VIServer -Server $server

if ($entity -ne "") {
	$vmtp = Get-VM -Location $entity
}
else {
	$vmtp = Get-VM
}
#$vmtp += Get-Template

<#
foreach($vm in $vmtp){
    $view = Get-View $vm
    if ($view.config.hardware.Device.Backing.ThinProvisioned -ne $true){
    #if ($view.config.hardware.Device.Backing.ThinProvisioned -eq $true){
        $row = '' | select Name, Provisioned, Total, Used, VMDKs, VMDKsize, DiskUsed, Thin
        $row.Name = $vm.Name
        $row.Provisioned = [math]::round($vm.ProvisionedSpaceGB , 2)
        $row.Total = [math]::round(($view.config.hardware.Device | Measure-Object CapacityInKB -Sum).sum/1048576 , 2)
        $row.Used = [math]::round($vm.UsedSpaceGB , 2)
        $row.VMDKs = $view.config.hardware.Device.Backing.Filename| Out-String
        $row.VMDKsize = $view.config.hardware.Device | where {$_.GetType().name -eq 'VirtualDisk'} | ForEach-Object {($_.capacityinKB)/1048576} | Out-String
        $row.DiskUsed = $vm.Extensiondata.Guest.Disk | ForEach-Object {[math]::round( ($_.Capacity - $_.FreeSpace)/1048576/1024, 2 )} | Out-String
        $row.Thin = $view.config.hardware.Device.Backing.ThinProvisioned | Out-String
        $report += $row
    }
}
#$report | Sort Name | Export-Csv -Path "C:\Thin_Disks.csv"
foreach($line in $report){
    Write-Host $line.Name"," $row.Thin
}
#>

foreach($vm in $vmtp | Get-View){
  foreach($dev in $vm.Config.Hardware.Device){
    if(($dev.GetType()).Name -eq "VirtualDisk"){
      if(!$dev.Backing.ThinProvisioned) {
        Write-Host $vm.Name  "`t"  $dev.Backing.FileName
        if ($SaveToFile -eq $true) {
	        $vm.Name  + "`t" + $dev.Backing.FileName | Out-File $path
        }

      }
    }
  }
}

