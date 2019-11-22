<#
#################################################################################
###Before you run this script run command below:

read-host -assecurestring | convertfrom-securestring | out-file C:\TEMP\secure.txt

Server names store in text file in: HostListFilePath
Lines starts with # as treated as comments
#################################################################################
#>

#################################################################################
$AddToDownadmin = $true
$DowntimeTime = 2   #in hours
$HostListFilePath = "C:\TEMP\hosts.txt"
$InstallFilePath = "\\server\dir\"
$username = "domain\username"
$password = cat C:\TEMP\secure.txt | convertto-securestring
$emailFrom = "vmwareToolsUpdate"
$emailTo = "user@lab.local"
$smtpServer = "smtp.lab.local"

#################################################################################

#get user password
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
#get servers list
$vms = Get-Content $HostListFilePath 

foreach ($vm in $vms){
    #check for comments
    if($vm.StartsWith("#") -ne $true){
        #check if server is alaiable 
	    $PingStatus = Gwmi Win32_PingStatus -Filter "Address = '$vm'" | Select-Object StatusCode
        
        If ($PingStatus.StatusCode -eq 0){
            #enable downtime
	        if ($AddToDownadmin){
		        downadmin -m $vm -hours $DowntimeTime -comment "NetBackup Client update"
	        }
            
            Update-Tools -NoReboot $vm

            $report += $vm + "Updated: " + "`r`n"             
            Write-Host  $vm " - Updated"              

        }
        else{
            $report +=  $vm + "- Unreachable"
            Write-Host $vm "- Unreachable"
        }

    }  

    Sleep 30  
    #Send out an email with the names  
    $subject = "VMware Tools Updated Report"  
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)  
    $smtp.Send($emailFrom, $emailTo, $subject, $report)

}
