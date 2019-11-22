#Add-PSSnapin VMware.VimAutomation.Core
#Add-PSSnapin VMware.VumAutomation
########################################################################
### GLOBALS ###
#Change this if you want to change the report save path 

$NTPServer1 = "10.10.0.8"
$NTPServer2 = "10.10.0.9"
$vcenter = "vc01.lab.local","vc02.lab.local" 

########################################################################

foreach($esx in $vcenter){

Connect-VIServer -Server $esx -User "root" -Password "XXXXX" | Out-Null

    #Configure NTP server
    Add-VmHostNtpServer -VMHost $esx -NtpServer $NTPServer1 -Confirm:$false
    Add-VmHostNtpServer -VMHost $esx -NtpServer $NTPServer2 -Confirm:$false

    #Allow NTP queries outbound through the firewall
    #Get-VMHostFirewallException -VMHost $vcenter | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true

    #Start NTP client service and set to automatic
    #Get-VmHostService -VMHost $vcenter | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService
    #Get-VmHostService -VMHost $vcenter | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic"
    $a = Get-VMHostService -VMHost $esx | where{$_.Key -eq "ntpd"} 
    Set-VMHostService -HostService $a -Policy "On" -Confirm:$false
    Get-VMHostService -VMHost $esx | where{$_.Key -eq "ntpd"} | Restart-VMHostService -Confirm:$false

}
