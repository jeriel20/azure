#requires -version 3
##########################################################################
# Script Name   :  ADinstall-2008.ps1
# Version       :  9.0
# Creation Date :  15 January 2014
# Created By    :  Software Engineering Center
#               :  Aberdeen Proving Grounds (APG), MD
# Prerequisites :  W2K8 R2, PowerShell 3.0
# Files         :  ADinstall-2008.ps1   (this file)
#               :  bccslib5r2.ps1
# Paths         :  Files must be located in C:\Scripts directory
##########################################################################
#  Installation and Configuration Variables
##########################################################################

$scriptver = "9.0"
$reqlibver = "9.5"
$title = "Active Directory Installation"

##########################################################################
# Forest/Domain Functional Level Values
# A value of 0 specifies Windows 2000
# A value of 2 specifies Windows Server 2003
# A value of 3 specifies Windows Server 2008
# A value of 4 specifies Windows Server 2008 R2
##########################################################################

$level = "4"

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

"===== START INSTALLATION - ADinstall-2008.ps1 =====" | Write-log

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

if(!(test-path "C:\Scripts\ADinstall-2008.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: ADinstall-2008.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

"ADinstall-2008.ps1 location ok" | Write-log

##########################################################################
# Verify .NET v4
##########################################################################

$fwlist = get-Framework-Versions

if($fwlist -contains "4.0")
{
   ".NET v4 Installed" | Write-log
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script requires .NET Framework v4 `n`n"
   "MISSING .NET FRAMEWORK v4" | Write-log
   EXIT
}

##########################################################################
# Verify W2K8 R2
##########################################################################

$OSver = get-OS

If($OSver -eq "W2K8R2SP1")
{
   "OS VERSION: $OSver" | Write-log
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script requires Windows Server 2008 R2 with Service Pack 1 `n`n"
   "INVALID OS: $OSver" | Write-log
   EXIT
}

##########################################################################
# License Statement and Acknowledgement
##########################################################################

$answer = get-LicenseACK

"License Response: $answer" | Write-log

If($answer -ne "Y") { EXIT }

##########################################################################
# System Requirements
##########################################################################

displayMainHeader $title

displayString " This script will configure the server to function as the FIRST domain controller in a NEW Active Directory domain OR promote a member server as an additional domain controller."
Write-Host

$prereqs="Windows Server 2008",".NET Framework 4.5","PowerShell version 3"
displayActionList "System Requirements" $prereqs

$prereqs="ONE (1) ENABLED NIC connected to the [Public Network]","The PUBLIC IP Address for the domain controller","The Fully Qualified Domain Name and NetBIOS Name for the domain"
displayActionList "FIRST DOMAIN CONTROLLER" $prereqs

$prereqs="ONE (1) ENABLED NIC connected to the [Public Network]","Member server (already joined to the domain)"
displayActionList "ADDITIONAL DOMAIN CONTROLLERS" $prereqs

$prereqs="FIRST DC: Configure the NIC with the Public IP Address, Netmask, and Gateway","Generate an answer file for DCPROMO with provided FQDN and NetBIOS names","Execute dcpromo.exe with the generated answer file","Forest and Domain Functional Levels will be set to Windows 2008 R2"
displayActionList "This script will complete the following tasks" $prereqs

displayLine
Write-Host

##########################################################################
# See if the user wants to proceed with the installation
##########################################################################

$yn = get-Response "Do You Wish to Proceed (Y/N)?" "CYAN" "Y"

If($yn -ne "Y") 
{
   "USER EXIT: Prequisites Display" | Write-log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT 
}

displayMainHeader $title

##########################################################################
# Determine if this is the FIRST DC or Member server
##########################################################################

# ------------------
# Logged on locally?
# ------------------

if($env:computername -eq $env:userdomain)
{
   $firstDC = get-Response "Is this the FIRST domain controller for a NEW domain?" "CYAN" "Y"

   If($firstDC -ne "Y")
   {
      Write-host -foregroundcolor WHITE "`n You must be logged onto the domain with the`n domain administrator account to promote additional DCs !`n`n"
      EXIT
   }
}
else
{
   $firstDC = "N"
}

If($firstDC -eq "Y")
{
   # -----------------------
   # Get PUBLIC NIC Settings
   # -----------------------

   Write-Host
   displaySubHeader "PUBLIC NIC Settings"

   $IPpublicAddress = get-ipv4Response "PUBLIC IP Address"
   $IPpublicMask = get-ipv4Response "PUBLIC IP NetMask" "CYAN" "255.255.255.0"
   $defaultGW = $IPpublicAddress.substring(0,$IPpublicAddress.LastIndexof(".")) + ".254"
   $IPpublicGateway = get-ipv4Response "PUBLIC IP Gateway" "CYAN" "$defaultGW"

   "IP Address: $IPpublicAddress" | Write-log
   "Netmask: $IPpublicMask" | Write-log
   "Gateway: $IPpublicGateway" | Write-log

   # ---------------------------
   # Get Domain NetBIOS and FQDN
   # ---------------------------

   Write-Host
   displaySubHeader "DOMAIN Settings"
   $netname = get-Response "Enter the NetBIOS (Short) domain name (ie. 25ID)"
   $defaultfqdn = $netname + ".ARMY.SMIL.MIL"
   $fqdn = get-Response "Enter the Fully Qualified Domain Name" "CYAN" "$defaultfqdn"
   "NetBIOS Name: $netname" | Write-log
   "FQDN: $fqdn" | Write-log

   # --------------------------------
   # Prompt for Restore Mode Password
   # --------------------------------

   $securepwd = get-Password "Safe Mode Administrative Password"
   $pwd = ConvertTo-PlainText($securepwd)

   "Restore Mode Password Provided" | Write-log

   # -------
   # Confirm
   # -------

   displayMainHeader $title

   displaySubHeader "CONFIRM SETTINGS"

   Write-Host -foregroundcolor YELLOW "`n PUBLIC NIC Settings`n"
   Write-Host -foregroundcolor WHITE  "`tIP Address : $IPpublicAddress"
   Write-Host -foregroundcolor WHITE  "`tIP NetMask : $IPpublicMask"
   Write-Host -foregroundcolor WHITE  "`tIP Gateway : $IPpublicGateway"

   Write-Host -foregroundcolor YELLOW "`n DOMAIN Settings`n"
   Write-Host -foregroundcolor WHITE  "`tNetBIOS    : $netname"
   Write-Host -foregroundcolor WHITE  "`tFQDN       : $fqdn"
   Write-Host
   displayLine
   Write-Host
   $go = get-Response "Do You Wish to Continue (Y/N)?" "CYAN" "Y"

   If($go -ne "Y") 
   {
      "USER EXIT: Confirmation Display" | Write-log
      "===== STOP INSTALLATION =====" | Write-log
      EXIT 
   }

   # ----------
   # PUBLIC NIC
   # ----------
   
   $adapter = get-wmiobject win32_networkadapterconfiguration -Filter 'ipenabled = "true"'
   $idx     = $adapter.index
   $nicname = gwmi win32_networkadapter -filter "index = $idx" | Select-Object -ExpandProperty NetConnectionID

   displayMainHeader $title

   displayMessage "Configuring PUBLIC NIC" "CYAN"

   & netsh interface ip set address name="$nicname" source=static addr=$IPpublicAddress gateway=$IPpublicGateway mask=$IPpublicMask gwmetric=1 | out-null
   & netsh interface ip set dns name="$nicname" source=static addr=$IPpublicAddress register=both | out-null

   displayStatus

   "NIC Configured: $nicname, $IPpublicAddress, $IPpublicGateway, $IPpublicMask" | Write-log

}
else
{
   # ---------------------------
   # Verify Domain Administrator
   # ---------------------------

   displayMessage "Verifying Domain Administrator Rights" "CYAN"

   $result = get-groupMembership $env:username "Domain Admins"

   If($result -eq 0)
   {
      displayStatus 2
      Write-Host -foregroundcolor YELLOW "`n`t$env:username is not a member of the Domain Admins Group!`n`n"
      "ERROR: $ENV:Username Not In Domain Administrators Group" | Write-Log
      "===== STOP INSTALLATION =====" | Write-log
      EXIT
   }

   displayStatus

   "$env:username in Domain Administrators Group" | Write-log   

}

# ------------------
# Create Answer File
# ------------------

$dcanswer = New-Item -ItemType file C:\scripts\dcanswer.txt -force

add-content $dcanswer "[DCINSTALL]"

if($firstDC -eq "Y")
{

   add-content $dcanswer "InstallDNS=yes"
   add-content $dcanswer "NewDomain=forest"
   add-content $dcanswer "NewDomainDNSName=$fqdn"
   add-content $dcanswer "DomainNetBiosName=$netname"
   add-content $dcanswer "ReplicaOrNewDomain=domain"
   add-content $dcanswer "ForestLevel=$level"
   add-content $dcanswer "DomainLevel=$level"
   add-content $dcanswer "RebootOnCompletion=yes"
   add-content $dcanswer "SafeModeAdminPassword=$pwd"

}
else
{

   # ----------------
   # Global Catalog ?
   # ----------------

   $gc  = get-Response "Configure as Global Catalog" "CYAN" "Y"

   # ------------
   # DNS Server ?
   # ------------

   $dns = get-Response  "Configure as a secondary DNS server" "CYAN" "Y"

   # --------------------------------
   # SAFE MODE Password
   # --------------------------------

   $securepwd = get-Password "Safe Mode Administrative Password" "CYAN"
   $pwd = ConvertTo-PlainText($securepwd)

   "Restore Mode Password Provided" | Write-log

   $fqdn = $env:userdnsdomain

   if( $gc -ne "Y" ) { $gc  = "no" } else { $gc  = "yes" }
   if( $dns -ne "Y") { $dns = "no" } else { $dns = "yes" } 

   add-content $dcanswer "InstallDNS=$dns"
   add-content $dcanswer "ConfirmGc=$gc"
   add-content $dcanswer "replicaOrNewDomain=replica"
   add-content $dcanswer "RebootOnCompletion=yes"
   add-content $dcanswer "SafeModeAdminPassword=$pwd"
   add-content $dcanswer "UserDomain=$fqdn"
   add-content $dcanswer "ReplicaDomainDNSName=$fqdn"

}

"Generated dcanswer.txt file for Unattended DCPROMO" | Write-log

if($firstDC -eq "Y")
{           

   displayMessage " Configuring Domain Controller " "CYAN"

   Write-Host -foregroundcolor WHITE  "`n`n Server will REBOOT when Complete!"
   Write-Host -foregroundcolor YELLOW "`n Run ADpostinstall.ps1 script after reboot to continue automated configuration.`n" 

   Pause "Press Any Key to run DCPROMO ... " "WHITE"

}

Clear-Host

Write-host

"Starting DCPROMO" | Write-log

& dcpromo /unattend:c:\scripts\dcanswer.txt

##########################################################################