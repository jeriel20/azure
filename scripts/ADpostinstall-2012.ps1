#requires -version 3
##########################################################################
# Script Name   :  ADpostinstall-2012.ps1
# Version       :  10.0
# Creation Date :  1 October 2015
# Created By    :  Software Engineering Center
#               :  Aberdeen Proving Grounds (APG), MD
# Prerequisites :  Windows 2012, PowerShell 3.0, .NET 4.5
# Files         :  ADpostinstall-2012.ps1
#               :  bccslib5r2.ps1
# Paths         :  Files must be located in C:\Scripts directory
# Version 10.0  :  2014/11/25
#               :  New AD and DNS cmdlets
#               :  Does NOT use dnscmd.exe
##########################################################################

##########################################################################
#  Installation and Configuration Variables
##########################################################################

$scriptver = "10.0"
$reqlibver = "9.5"
$title = "Active Directory Post-Installation"

##########################################################################
# Log filename used by the logging routine (Write-log)
##########################################################################

$currdate = get-date -format "yyyyMMdd"
$logfile = $ENV:COMPUTERNAME + "_postinstall_" + $currdate + ".log"

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

"===== START INSTALLATION - ADpostinstall-2012.ps1 =====" | Write-log

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

if(!(test-path "C:\Scripts\ADpostinstall-2012.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: ADpostinstall-2012.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

"ADpostinstall-2012.ps1 location ok" | Write-log

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
# Verify server is a domain controller
##########################################################################

$result = get-Service ADWS -EA SilentlyContinue

If($result -eq $null)
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script must be run on a Domain Controller !!!`n`n"
   "INVALID SERVER: Not a Domain Controller" | Write-log
   EXIT
}

##########################################################################

displayMainHeader $title

displayString "This script CONTINUES the configuration of the first domain controller AFTER successfully completing the ADinstall.ps1 script."
Write-Host

$prereqs="Create DNS Forward Lookup Zone (DS)","Create DNS Reverse Lookup Zone","Create DNS Root Lookup Zone (block RootHints)","Enable Scavenging on all Zones","Set Tombstone Lifetime to 365 Days"
displayActionList "The following tasks will be accomplished" $prereqs

$prereqs="Create BCCS Accounts","Create DCGS-A OU Structure and Accounts","Create Command Web Structure and Accounts","Create C2I Security Groups","Create GCCS-A Groups and Accounts"
displayActionList "Optional Tasks" $prereqs

displayLine
Write-Host

if(test-path "C:\Scripts\modSchema-2012.ps1")
{
   $goSchema   = get-Response "Apply DOD Schema Modifications (Y/N)?" "CYAN" "Y" 
}

if(test-path "C:\Scripts\createAccounts-2012.ps1")
{
   $goBCCS   = get-Response "Create BCCS Service Accounts (Y/N)?" "CYAN" "Y" 
}

if(test-path "C:\Scripts\createDCGSaccounts-2012.ps1")
{
   $goDCGS   = get-Response "Create DCGS-A OU Structure, Security Groups, and Accounts (Y/N)?" "CYAN" "N"
}

if(test-path "C:\Scripts\createCMDWEB-2012.ps1")
{
   $goCMDWEB = get-Response "Create Command Web OU Structure, Security Groups, and Accounts (Y/N)?" "CYAN" "N"
}

if(test-path "C:\Scripts\createC2Iaccounts-2012.ps1")
{
   $goC2I = get-Response "Create C2I Security Groups (Y/N)?" "CYAN" "N"
}

if(test-path "C:\Scripts\createGCCS4.3accounts-2012.ps1")
{
   $goGCCS = get-Response "Create GCCS-A 4.3 OU Structure, Security Groups, and Accounts (Y/N)?" "CYAN" "N"
}

displayMainHeader $title

##########################################################################
# Create DNS Forward Zone (.DS.ARMY.SMIL.MIL)
##########################################################################

"===== START FORWARD LOOKUP ZONE CREATION =====" | Write-log

Write-Host -foregroundcolor CYAN " Create DNS Lookup Zones"
Write-Host

$fqdn = $env:userdnsdomain
$primaryZone = $fqdn.Split(".")

if(!($fqdn -like "*.DS.*"))
{
   $forwardZone = ""
   foreach ($octet in $primaryZone)
   {
      if($octet -eq "army")
      {
         $forwardZone = $forwardZone + "DS." + $octet + "."
      }
      else
      {
         $forwardZone = $forwardZone + $octet + "."
      }
   }
   $len = $forwardZone.length
   $forwardZone = $forwardZone.substring(0,$len-1)
}
else
{
   $forwardZone = $fqdn
}

"Forward Zone: $forwardZone" | Write-log

displayMessage "    Forward Zone $forwardZone " "WHITE"

$zonetest=get-DnsServerZone -Name $forwardZone -ErrorAction SilentlyContinue  

If($zonetest -ne $null)
{
  displayStatus 3
  "Forward Lookup Zone ($forwardZone) Already Exists" | Write-log
}
else
{
   $newZone = Add-DnsServerPrimaryZone -Name $forwardZone -ReplicationScope "Domain" -PassThru

   if($newZone.ZoneName -eq "$forwardZone")
   {
      displayStatus
      "Created Forward Lookup Zone ($forwardZone)" | Write-log
   }
   else
   {
      displayStatus 2
      "Error Creating New Zone ($forwardZone)" | Write-log
   }
}

"===== COMPLETED FORWARD LOOKUP ZONE CREATION =====" | Write-log

##########################################################################
# Create DNS Reverse Zone
##########################################################################

"===== START REVERSE LOOKUP ZONE CREATION =====" | Write-log

$ifidx  = (get-NetAdapter).interfaceindex
$mask   = (get-NetIPAddress -InterfaceIndex $ifidx -AddressFamily IPv4).PrefixLength
$ipv4   = (get-NetIPAddress -InterfaceIndex $ifidx -AddressFamily IPv4).IPAddress
$ipaddr = $ipv4.Split(".")

$ipMask = $ipaddr[0] + "." + $ipaddr[1] + "." + $ipaddr[2] + ".0/" + "$mask"
$reverse = $ipaddr[2] + "." + $ipaddr[1] + "." + $ipaddr[0] + ".in-addr.arpa"

"Reverse IP Address: $reverse" | Write-log

displayMessage "    Reverse Zone $reverse " "WHITE"

$zonetest = get-DnsServerZone -Name $reverse -ErrorAction SilentlyContinue

If($zonetest -ne $null)
{
  displayStatus 3
  "Reverse Lookup Zone ($reverse) Already Exists" | Write-log
}
else
{
   $NewZone = Add-DnsServerPrimaryZone -NetworkID $ipMask -ReplicationScope Domain -PassThru
   
   if($newZone.ZoneName -eq "$reverse")
   {
      displayStatus
      "Created Reverse Lookup Zone ($reverse)" | Write-log
   }
   else
   {
      displayStatus 2
      "Error Creating New Zone ($reverse)" | Write-log
   }   
}

"===== COMPLETED REVERSE LOOKUP ZONE CREATION =====" | Write-log

##########################################################################
# Create .(root) Zone - to block roothints
##########################################################################

"===== START ROOT LOOKUP ZONE CREATION =====" | Write-log

$rootZone = "."

"ROOT Zone: $rootZone" | Write-log

displayMessage "    Root Zone .(root) " "WHITE"

$zonetest = get-DnsServerZone -Name $rootZone -ErrorAction SilentlyContinue

If($zonetest -ne $null)
{
  displayStatus 3
  "Forward Lookup Zone ($rootZone) Already Exists" | Write-log
}
else
{
   $newZone = Add-DnsServerPrimaryZone -Name $rootZone -ReplicationScope "Domain" -PassThru

   if($newZone.ZoneName -eq "$rootZone")
   {
      displayStatus
      "Created Forward Lookup Zone ($rootZone)" | Write-log
   }
   else
   {
      displayStatus 2
      "Error Creating New Zone ($rootZone)" | Write-log
   }
}

##########################################################################
# Turn on Scavenging
##########################################################################

displayMessage " Enable Scavenging on all zones " "CYAN"

$scavengeCheck = Set-DnsServerScavenging -ApplyOnAllZones -RefreshInterval 1.00:00:00 -ScavengingState:$true -PassThru -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

displayStatus

"Scavenging Turned on" | out-null

##########################################################################
# Increase Tombstone Lifetime to 1 Year (365 Days)
##########################################################################

displayMessage " Set Tombstone Lifetime to 365 Days " "CYAN"

import-module ActiveDirectory

$ADDomainName = Get-ADDomain

$ADname = $ADDomainName.DistinguishedName

Set-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$ADname" -Partition "CN=Configuration,$ADname" -Replace @{tombstoneLifetime='365'}

displayStatus

"Tombstone Lifetime set to 365 days" | out-null

##########################################################################
# Delete DNS Cache
##########################################################################

if(test-path "c:\windows\system32\dns\CACHE.DNS")
{
   Remove-Item "c:\windows\system32\dns\CACHE.DNS"
   "DNS Cache Deleted" | out-null
}

"===== COMPLETED ROOT LOOKUP ZONE CREATION =====" | Write-log

##########################################################################
# Update DNS Entries for Active NIC
##########################################################################

if(test-path "c:\scripts\firstDC.txt")
{
   $dnsResult = Set-DnsClientServerAddress -InterfaceIndex $ifidx -ServerAddresses ("$ipv4", "127.0.0.1") -Confirm:$false
}

##########################################################################

Write-Host
displayLine
Write-Host
pause
   
if($goSchema -eq "Y")
{
   . .\"modSchema-2012.ps1"
}

if($goBCCS -eq "Y")
{
   . .\"createAccounts-2012.ps1"
}

if($goDCGS -eq "Y")
{
   . .\"createDCGSaccounts-2012.ps1"
}

if($goCMDWEB -eq "Y")
{
   . .\"createCMDWEB-2012.ps1"
}
if($goC2I -eq "Y")
{
   . .\"createC2Iaccounts-2012.ps1"
}
if($goGCCS -eq "Y")
{
   . .\"createGCCS4.3accounts-2012.ps1"
}

##########################################################################
# Installation Complete: Copy shortcuts to desktop
##########################################################################
 
if (test-path "C:\Windows\system32\dsa.msc")
{
    $shell = New-Object -ComObject WScript.Shell
    $desktop = 'C:\Users\Public\Desktop'
    if(!(test-path "$desktop\Active Directory Users and Computers.lnk") )
    {
        $shortcut = $shell.CreateShortcut("$desktop\Active Directory Users and Computers.lnk")
        $shortcut.TargetPath = "C:\Windows\system32\dsa.msc"
        $shortcut.Save()
        Set-Location "C:\Scripts"
        "Copied Active Directory Users and Computers to Desktop" | Write-log
    }
}
 else
{
    Write-Host
    Write-host -foregroundcolor YELLOW " Could not find Active Directory Users and Computers Shortcut (?!?!?!)`n" 
    write-host 
    write-host -foregroundcolor YELLOW "`n`n Make sure AD Post Installation is complete!!!`n" 
    write-host
    Set-Location "C:\Scripts"
    "WARNING: Could not find Active Directory Users and Computers Shortcut" | Write-log
    Exit
}

if (test-path "C:\Windows\system32\dnsmgmt.msc") 
{
    $shell = New-Object -ComObject WScript.Shell
    $desktop = 'C:\Users\Public\Desktop'
    if(!(test-path "$desktop\DNS.lnk") )
    {
        $shortcut = $shell.CreateShortcut("$desktop\DNS.lnk")
        $shortcut.TargetPath = "C:\Windows\system32\dnsmgmt.msc"
        $shortcut.Save()
        Set-Location "C:\Scripts"
        "Copied DNS shortcut to Desktop" | Write-log
    }
}
 else
{
    Write-Host
    Write-host -foregroundcolor YELLOW " Could not find DNS Edit Shortcut (?!?!?!)`n" 
    write-host 
    write-host -foregroundcolor YELLOW "`n`n Make sure AD Post Installation is complete!!!`n" 
    write-host
    Set-Location "C:\Scripts"
    "WARNING: Could not find DNS Shortcut" | Write-log
    Exit
}
  

"===== COMPLETED INSTALLATION - ADpostinstall-2012.ps1 =====" | Write-log

##########################################################################