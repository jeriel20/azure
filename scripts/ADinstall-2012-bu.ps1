#requires -version 3
##########################################################################
# Script Name   :  ADinstall-2012.ps1
# Version       :  10.0
# Creation Date :  1 October 2015
# Created By    :  Software Engineering Center
#               :  Aberdeen Proving Grounds (APG), MD
# Prerequisites :  Windows 2012, PowerShell 3.0, .NET 4.5
# Files         :  ADinstall-2012.ps1   (this file)
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

"===== START INSTALLATION - ADinstall-2012.ps1 =====" | Write-log

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

if(!(test-path "C:\Scripts\ADinstall-2012.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: ADinstall-2012.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

"ADinstall-2012.ps1 location ok" | Write-log

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

##########################################################################
# Verify server is NOT a domain controller
##########################################################################

$result = get-Service ADWS -EA SilentlyContinue

If($result -ne $null)
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This server is already configured as a Domain Controller !!!`n`n"
   "INVALID SERVER: Already configured as a  Domain Controller" | Write-log
   EXIT
}

##########################################################################
# Verify only one active NIC
##########################################################################

$nic = get-NetAdapter | Where Status -eq "Up"
   
If (($nic.Count -ge 2) -or ($nic -eq $NULL))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Only ONE (1) Active Network Adapater Is Allowed on a DC `n`n"
   "MORE THAN ONE ACTIVE NETWORK ADAPTER" | Write-log
   EXIT
}

$nicName = $nic.Name
$nicIndex = $nic.InterfaceIndex

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

$prereqs="Windows Server 2012",".NET Framework 4.5","PowerShell version 3"
displayActionList "System Requirements" $prereqs

$prereqs="ONE (1) ENABLED NIC connected to the [Public Network]","The PUBLIC IP Address for the domain controller","The Fully Qualified Domain Name and NetBIOS Name for the domain"
displayActionList "FIRST DOMAIN CONTROLLER" $prereqs

$prereqs="ONE (1) ENABLED NIC connected to the [Public Network]","Member server (already joined to the domain)"
displayActionList "ADDITIONAL DOMAIN CONTROLLERS" $prereqs

$prereqs="FIRST DC: Configure the NIC with the Public IP Address, Netmask, and Gateway","Execute the Install-ADDSForest cmdlet with the provided settings","Forest and Domain Functional Levels will be set to Windows 2012"
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
      displayString "You must be logged onto the domain with the`n domain administrator account to promote additional DCs!" "Red"
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
   # Prompt for Safe Mode Password
   # --------------------------------

   $securepwd = get-Password "Safe Mode Administrative Password"
   $pwd = ConvertTo-PlainText($securepwd)

   "Safe Mode Password Provided" | Write-log

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
   displayMainHeader $title
   displayMessage "Configuring PUBLIC NIC" "CYAN"

   # ----------------------------------
   # Clear current NIC settings, if any
   # ----------------------------------
   $clrResults = clear-NICsettings $nicIndex
   
   # ----------------------
   # Apply new NIC settings
   # ----------------------
   $pfl = get-PrefixLength $IPpublicMask
   
   If($pfl -eq -1)
   {
      Clear-Host
      Write-Host -foregroundcolor YELLOW "`n Invalid Subnet Mask - $IPpublicMask `n`n"
      "INVALID SUBNET MASK ($IPpublicMask)" | Write-log
      EXIT
   }
   
   $nicResult = New-NetIPAddress –InterfaceIndex $nicIndex –IPAddress $IPpublicAddress -PrefixLength $pfl -DefaultGateway $IPpublicGateway
   $dnsResult = Set-DnsClientServerAddress -InterfaceIndex $nicIndex -ServerAddresses ("127.0.0.1") -Confirm:$false
   
   displayStatus

   "NIC Configured: $nicname, $IPpublicAddress, $IPpublicGateway, $IPpublicMask" | Write-log
}
else
{

   # ---------------------------
   # Verify Domain Administrator
   # ---------------------------

   displayMessage "Verifying Domain Administrator Rights"
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

   if( $gc -ne "Y" ) { $gc  = $true  } else { $gc  = $false }
   if( $dns -ne "Y") { $dns = $false } else { $dns = $true  } 
   
   Write-host " "

}

$ADavail = (get-WindowsFeature AD-Domain-Services).InstallState
   
displayMessage " Install Windows Feature: AD-Domain-Services " "CYAN"

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
   displayMessage " Configuring SECONDARY Domain Controller " "CYAN"
   $fqdn = $env:userdnsdomain
   $installResult = Install-ADDSDomainController -SafeModeAdministratorPassword $securePWD -DomainName "$fqdn" -NoGlobalCatalog:$gc -InstallDns:$dns -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -Force
   If($installResult.Status -eq "Success") { displayStatus } else { displayStatus 2 }
}
