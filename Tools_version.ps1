# List old tools versions on all vm's

param (
    [string]$server = "vc01.lab.local",
	[string]$entity = "", 
    [switch]$SaveToFile,
    [string]$path = [Environment]::GetFolderPath("Desktop") + "\VMwareOldToolsList.txt"
 )


function do_clear_screen(){
    clear
    Write-Host "#### VMware Tools version check ####"
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

$report = "VM Name `t HOST NAME `t TOOLS VER.`r`n"
foreach($vm in $vmtp){
	 if ($vm.ExtensionData.Guest.ToolsStatus -eq "ToolsOld"){
		$report += $vm.Name + "`t" + $vm.Host + "`t" + $vm.ExtensionData.Guest.ToolsVersion + "`r`n"
		Write-Host $vm.Name "`t" $vm.Host "`t" $vm.ExtensionData.Guest.ToolsVersion
	}
    if ($SaveToFile -eq $true) {
	    $report | Out-File $path
    }
}
