#requires -version 3
##########################################################################
# Script Name   :  ADpostinstall-2008.ps1
# Version       :  9.0
# Creation Date :  15 January 2014
# Created By    :  Software Engineering Center
#               :  Aberdeen Proving Grounds (APG), MD
# Prerequisites :  W2K8 R2, PowerShell 3.0
# Files         :  ADpostinstall-2008.ps1
#               :  bccslib5r2.ps1
# Paths         :  Files must be located in C:\Scripts directory 
#
# History       : 8.1 (2012/08/29)
#               :    - Added DCGS-A Account Creation script and .csv files
#               : 8.2 (2012/10/08)
#               :    - Added removal of Administration Center shortcut from desktop
#               : 8.3 (2013/01/15)
#                    - Added Scavenging to Zones
#                    - Added Tombstone Lifetime setting (365)
#                    - Added NIC DNS IP settings
#               : 8.4 (2013/08/20)
#                    - Updated for PSv3 (Required)
#                    - New method for retrieveing NIC information
##########################################################################

$scriptver = "9.0"
$reqlibver = "9.5"
$title = "Active Directory Post Installation"

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

"===== START INSTALLATION - ADpostinstall-2008.ps1 =====" | Write-log

##########################################################################
#  Start Processing
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

if(!(test-path "C:\Scripts\ADpostinstall-2008.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: ADpostinstall-2008.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

##########################################################################
# Don't run this script on additional domain controllers
##########################################################################

if(test-path "c:\scripts\dcanswer.txt")
{
   $dcanswer = get-content "c:\scripts\dcanswer.txt"
   if($dcanswer -contains "replicaOrNewDomain=replica")
   {
      Clear-Host
      Write-Host -foregroundcolor YELLOW "`n Script must not be run on additional domain controllers`n`n"
      "ERROR: User attempted to run ADpostinstall.ps1 on additional domain controller" | Write-Log
      "===== STOP INSTALLATION =====" | Write-log
      EXIT   
   }
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be run AFTER ADinstall.ps1`n`n"
   "ERROR: User attempted to run ADpostinstall.ps1 without running ADinstall.ps1" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
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

if(test-path "C:\Scripts\modSchema-2008.ps1")
{
   $goSchema   = get-Response "Apply DOD Schema Modifications (Y/N)?" "CYAN" "Y" 
}

if(test-path "C:\Scripts\createAccounts-2008.ps1")
{
   $goBCCS   = get-Response "Create BCCS Service Accounts (Y/N)?" "CYAN" "Y" 
}

if(test-path "C:\Scripts\createDCGSaccounts-2008.ps1")
{
   $goDCGS   = get-Response "Create DCGS-A OU Structure, Security Groups, and Accounts (Y/N)?" "CYAN" "N"
}

if(test-path "C:\Scripts\createCMDWEB-2008.ps1")
{
   $goCMDWEB = get-Response "Create Command Web OU Structure, Security Groups, and Accounts (Y/N)?" "CYAN" "N"
}

if(test-path "C:\Scripts\createC2Iaccounts-2008.ps1")
{
   $goC2I = get-Response "Create C2I Security Groups (Y/N)?" "CYAN" "N"
}

if(test-path "C:\Scripts\createGCCS4.3accounts-2008.ps1")
{
   $goGCCS = get-Response "Create GCCS-A 4.3 OU Structure, Security Groups, and Accounts (Y/N)?" "CYAN" "N"
}

displayMainHeader $title

##########################################################################
# Preferred and Secondary DNS IP Addresses
##########################################################################

$ip      = Get-WMIObject Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE
$idx     = $ip.index
$nicname = gwmi win32_networkadapter -filter "index = $idx" | Select-Object -ExpandProperty NetConnectionID
$ipv4 = $ip.IPAddress[0]

& netsh interface ip set dns name="$nicname" source=static addr=$ipv4 register=both | out-null
& netsh interface ip add dns name="$nicname" addr=127.0.0.1 | out-null

##########################################################################
# Copy Shortcuts to Desktop for All Users
##########################################################################

copy-item "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Active Directory Users and Computers.lnk" `
          "C:\Users\Public\Desktop"

"Copied [Users and Computers] Shortcut to Desktop" | Write-log

copy-item "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Administrative Tools\DNS.lnk" `
          "C:\Users\Public\Desktop"

"Copied [DNS] Shortcut to Desktop" | Write-log

##########################################################################
# Create DNS Forward Zone (.DS.ARMY.SMIL.MIL)
##########################################################################

"===== START FORWARD LOOKUP ZONE CREATION =====" | Write-log

Write-Host -foregroundcolor CYAN "`n Create DNS Lookup Zones `n"

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

$zonetest=Get-WMIObject -Class MicrosoftDNS_Zone -Namespace root\MicrosoftDNS | Where-Object{$_.Name -eq $forwardZone}  

If($zonetest -ne $null)
{
  displayStatus 3
  "Forward Lookup Zone ($forwardZone) Already Exists" | Write-log
}
else
{

   $NewZone = ([WMIClass]"\\.\root\MicrosoftDNS:MicrosoftDNS_Zone").CreateZone("$forwardZone", 0, $True) 
   displayStatus
   "Created Forward Lookup Zone ($forwardZone)" | Write-log
}

# This is deprecated but no way to do this using WMI (so far)

& dnscmd /Config $forwardZone /AllowUpdate 2 | out-null

"Forward Lookup Zone set to allow secure updates" | Write-log

If($LASTEXITCODE -ne "0")
{
   Write-Host -foregroundcolor YELLOW "WARNING: Could Not Set Update Level for Forward Lookup Zone!`n"
   "Error Setting Update Level ($forwardZone)" | Write-log
}

"===== COMPLETED FORWARD LOOKUP ZONE CREATION =====" | Write-log

##########################################################################
# Create DNS Reverse Zone
##########################################################################

"===== START REVERSE LOOKUP ZONE CREATION =====" | Write-log

$ipaddr = $ipv4.Split(".")

$reverse = $ipaddr[2] + "." + $ipaddr[1] + "." + $ipaddr[0] + ".in-addr.arpa"

"Reverse IP Address: $reverse" | Write-log

displayMessage "    Reverse Zone $reverse " "WHITE"

$zonetest=Get-WMIObject -Class MicrosoftDNS_Zone -Namespace root\MicrosoftDNS | Where-Object{$_.Name -eq $reverse}  

If($zonetest -ne $null)
{
  displayStatus 3
  "Reverse Lookup Zone ($reverse) Already Exists" | Write-log
}
else
{
   $NewZone = ([WMIClass]"\\.\root\MicrosoftDNS:MicrosoftDNS_Zone").CreateZone("$reverse", 0, $True) 
   displayStatus
   "Created Lookup Zone ($reverse)" | Write-log
}

# This is deprecated but no way to do this using WMI (so far)

dnscmd /Config $reverse /AllowUpdate 2 | out-null

"Reverse Lookup Zone set to allow updates" | Write-log

If($LASTEXITCODE -ne "0")
{
   Write-Host -foregroundcolor YELLOW "WARNING: Could Not Set Update Level for Reverse Lookup Zone!`n"
   "Error Setting Update Level ($reverse)" | Write-log
}

"===== COMPLETED REVERSE LOOKUP ZONE CREATION =====" | Write-log

##########################################################################
# Create .(root) Zone - to block roothints
##########################################################################

"===== START ROOT LOOKUP ZONE CREATION =====" | Write-log

$rootZone = "."

"ROOT Zone: $rootZone" | Write-log

displayMessage "    Root Zone .(root) " "WHITE"

if(test-path "c:\Scripts\hold.txt")
{
   Remove-Item "c:\Scripts\hold.txt"
}

$computer = $env:computername

& dnscmd.exe $computer /zoneinfo "." > c:\scripts\hold.txt

$rootCheck = Select-String c:\scripts\hold.txt -pattern "DC=.,cn=MicrosoftDNS"

If($rootCheck)
{
  displayStatus 3
  "Root Lookup Zone ($rootZone) Already Exists" | Write-log
}
else
{
   $NewZone = ([WMIClass]"\\.\root\MicrosoftDNS:MicrosoftDNS_Zone").CreateZone("$rootZone", 0, $True) 
   displayStatus
   "Created Root Lookup Zone ($rootZone)" | Write-log
}

if(test-path "c:\Scripts\hold.txt")
{
   Remove-Item "c:\Scripts\hold.txt"
}

# This is deprecated but no way to do this using WMI (so far)

& dnscmd /Config $rootZone /AllowUpdate 2 | out-null

"ROOT Lookup Zone set to allow updates" | Write-log

If($LASTEXITCODE -ne "0")
{
   Write-Host -foregroundcolor YELLOW "WARNING: Could Not Set Update Level for ROOT Lookup Zone!`n"
   "Error Setting Update Level ($rootZone)" | Write-log
}
##########################################################################
# Turn on Scavenging
##########################################################################

displayMessage " Enable Scavenging on all zones " "CYAN"

$mainZone = $env:userDNSdomain

& dnscmd /Config $mainZone    /Aging 1 | out-null
& dnscmd /Config $forwardZone /Aging 1 | out-null
& dnscmd /Config $reverse     /Aging 1 | out-null
& dnscmd /Config $rootZone    /Aging 1 | out-null

displayStatus

"Scavenging Turned on" | out-null

##########################################################################
# Increase Tombstone Lifetime to 1 Year (365 Days)
##########################################################################

displayMessage "Set Tombstone Lifetime to 365 Days"
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
# Delete Root Hints
##########################################################################
#
#"===== START DELETE ROOTHINT ENTRIES =====" | Write-log
#displayMessage "    Delete RootHints " "WHITE"
#& dnscmd.exe /RecordDelete /RootHints `@ NS /f | out-null
#& dnscmd.exe /RecordDelete /RootHints `@ A /f  | out-null
#If($LASTEXITCODE -ne "0")
#{
#   Write-Host -foregroundcolor YELLOW "WARNING: Could Not Delete RootHints!`n"
#   "Error Deleting RootHints" | Write-log
#   displayStatus 2
#}
#else
#{
#   displayStatus
#   "ROOT Lookup Zone Records Deleted" | Write-log
#}
#"===== COMPLETED DELETION OF ROOTHINTS =====" | Write-log
#if(test-path "c:\windows\system32\dns\CACHE.DNS")
#{
#   Remove-Item "c:\windows\system32\dns\CACHE.DNS"
#}
#& dnscmd.exe /RecordDelete /RootHints `@ NS /f | out-null
#& dnscmd.exe /RecordDelete /RootHints `@ A /f  | out-null
#
##########################################################################

displayLine
Write-Host

pause
   
if($goSchema -eq "Y")
{
   . .\"modSchema-2008.ps1"
}

if($goBCCS -eq "Y")
{
   . .\"createAccounts-2008.ps1"
}

if($goDCGS -eq "Y")
{
   . .\"createDCGSaccounts-2008.ps1"
}

if($goCMDWEB -eq "Y")
{
   . .\"createCMDWEB-2008.ps1"
}

if($goC2I -eq "Y")
{
   . .\"createC2Iaccounts-2008.ps1"
}

if($goGCCS -eq "Y")
{
   . .\"createGCCS4.3accounts-2008.ps1"
}

"===== COMPLETED INSTALLATION - ADpostinstall-2008.ps1 =====" | Write-log

##########################################################################
