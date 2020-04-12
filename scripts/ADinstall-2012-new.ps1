#requires -version 3
##########################################################################
# Script Name   :  ADinstall-2012-new.ps1
# Version       :  10.0
# Creation Date :  2020-APR
# Prerequisites :  Windows 2012, PowerShell 3.0, .NET 4.5
# Files         :  ADinstall-2012-new.ps1   (this file)
#               :  bccslib5r2.ps1
# Paths         :  Files must be located in C:\Scripts directory
# Version 10.0  :  2014/11/25
#                  DEL: dcpromo.exe code (all cmdlets)
##########################################################################

##########################################################################
#  Installation and Configuration Variables
##########################################################################

$scriptver = "10.0"
$reqlibver = "9.5"
$title = "Active Directory Installation"

##########################################################################
# Forest/Domain Functional Level Values
# A value of 0 specifies Windows 2000
# A value of 2 specifies Windows Server 2003
# A value of 3 specifies Windows Server 2008
# A value of 4 specifies Windows Server 2008 R2
# A value of 5 specifies Windows Server 2012
##########################################################################

$level = "5"

##########################################################################
# Log filename used by the logging routine (Write-log)
##########################################################################

$currdate = get-date -format "yyyyMMdd"
$logfile = $ENV:COMPUTERNAME + "_install_" + $currdate + ".log"

##########################################################################
# Include the library routines (DOT Source)
##########################################################################

if(!(test-path "c:\Scripts\bccslib5r2.ps1"))
{
    Clear
    Write-Host -foregroundcolor Yellow "`n Missing bccslib5r2.ps1 - Ensure this file is in the c:\Scripts Directory`n`n"
    Exit
}

. ./bccslib5r2.ps1

if([int]$BCCSLibver -lt [int]$reqlibver)
{
    Clear
    Write-Host -foregroundcolor Yellow "`n Incorrect BCCS Library - Must be Version $reqlibver or Higher`n`n"
    Exit
}

##########################################################################
#  Start Log
##########################################################################

"===== START INSTALLATION - ADinstall-2012-new.ps1 =====" | Write-log

##########################################################################
# START PROCESSING
##########################################################################

$header = Set-Console $title
$header | Write-log
setWindowSize

##########################################################################
# Verify the C:\Scripts directory exists and set to default location
##########################################################################

if(!(test-path "C:\Scripts"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: Script not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

set-location "C:\Scripts"

if(!(test-path "C:\Scripts\ADinstall-2012-new.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: ADinstall-2012.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

"ADinstall-2012-new.ps1 location ok" | Write-log

##########################################################################
# Verify Windows Server 2012
##########################################################################

$OSver = get-OS

If($OSver -eq "W2012R2")
{
   "OS VERSION: $OSver" | Write-log
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script requires Windows Server 2012 R2`n`n"
   "INVALID OS: $OSver" | Write-log
   EXIT
}

##########################################################################
# Verify .NET v4.5
##########################################################################

$net45 = $FALSE
$net45 = (get-WindowsFeature -Name NET-Framework-45-Features).Installed

if($net45)
{
   ".NET v4.5 Installed" | Write-log
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script requires .NET Framework v4.5 `n`n"
   "MISSING .NET FRAMEWORK v4.5" | Write-log
   EXIT
}

$firstDC = "Y"

If($firstDC -eq "Y")
   # ---------------------------
   # NIC Settings
   # ---------------------------
{
   Write-Host
   displaySubHeader "PUBLIC NIC Settings"

   $IPpublicAddress = "10.0.0.4"
   $IPpublicMask = "255.255.255.0"
   $defaultGW = "10.0.0.1"
   $IPpublicGateway = "$defaultGW"

   "IP Address: $IPpublicAddress" | Write-log
   "Netmask: $IPpublicMask" | Write-log
   "Gateway: $IPpublicGateway" | Write-log

   # ---------------------------
   # Domain NetBIOS and FQDN
   # ---------------------------

   Write-Host
   displaySubHeader "DOMAIN Settings"
   $netname = "3SBCT2ID"
   $defaultfqdn = $netname + ".ARMY.MIL"
   $fqdn = "$defaultfqdn"
   "NetBIOS Name: $netname" | Write-log
   "FQDN: $fqdn" | Write-log

   # --------------------------------
   # Safe Mode Password
   # --------------------------------

   $securepwd = "Fh5@#250@!1cgI#"
   $pwd = ConvertTo-PlainText($securepwd)

   "Safe Mode Password Provided" | Write-log

   # -------
   # Confirm
   # -------

   displayMainHeader $title
   displaySubHeader "SETTINGS"

   Write-Host -foregroundcolor YELLOW "`n PUBLIC NIC Settings`n"
   Write-Host -foregroundcolor WHITE  "`tIP Address : $IPpublicAddress"
   Write-Host -foregroundcolor WHITE  "`tIP NetMask : $IPpublicMask"
   Write-Host -foregroundcolor WHITE  "`tIP Gateway : $IPpublicGateway"

   Write-Host -foregroundcolor YELLOW "`n DOMAIN Settings`n"
   Write-Host -foregroundcolor WHITE  "`tNetBIOS    : $netname"
   Write-Host -foregroundcolor WHITE  "`tFQDN       : $fqdn"
}
else
{
   displayMessage "Troubleshoot this script"
}

$ADavail = "Available"
   
displayMessage " Installing Windows Feature: AD-Domain-Services " "CYAN"

if($ADavail -eq "Installed")
{
   displayStatus 5
   "AD DOMAIN SERVICES Already Installed" | Write-log
}
elseif($ADavail -eq "Available")
{
   $installResult = Install-WindowsFeature –Name AD-Domain-Services -IncludeManagementTools -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
   If($installResult.ExitCode -ne "Success")
   {
      displayStatus 2
      Write-Host -foregroundcolor YELLOW "`n`tAD Domain Services Installation FAILED`n`n"
      "ERROR: AD Domain Services Installation FAILED" | Write-Log
      "===== STOP INSTALLATION =====" | Write-log
      EXIT
   }
   else
   {
      displayStatus
      "AD-Domain-Services Installed" | Write-log
   }
}
else
{
   displayStatus 2
   "ERROR INSTALLING AD Domain Services ($ADavail)" | Write-log
   Exit
}

Import-Module ADDSDeployment

sleep 5

if($firstDC -eq "Y")
{
   $newDC = New-Item c:\scripts\firstDC.txt -type file -force
   displayMessage " Configuring FIRST Domain Controller " "CYAN"
   $installResult = Install-ADDSForest -SafeModeAdministratorPassword $securePWD -DomainMode "$level" -DomainName "$fqdn" -DomainNetbiosName "$netname" -ForestMode "$level" -InstallDns -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force
   If($installResult.Status -eq "Success") { displayStatus } else { displayStatus 2 }

}
else
{
   displayMessage "Troubleshoot this script" "CYAN"
}
