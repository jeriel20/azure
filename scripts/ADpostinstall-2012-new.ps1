#requires -version 3
##########################################################################
# Script Name   :  ADpostinstall-2012-new.ps1
# Version       :  10.0
# Creation Date :  12-APR-2020
# Prerequisites :  Windows 2012, PowerShell 3.0, .NET 4.5
# Files         :  ADpostinstall-2012.ps1
#               :  bccslib5r2.ps1
# Paths         :  Files must be located in C:\Scripts directory
# Version 10.0  :  2014/11/25
#               :  New AD and DNS cmdlets
#               :  Does NOT use dnscmd.exe
##########################################################################
. ./bccslib5r2.ps1
set-location "C:\Scripts"
##########################################################################
# Create DNS Forward Zone (.DS.ARMY.SMIL.MIL)
##########################################################################
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

$zonetest=get-DnsServerZone -Name $forwardZone -ErrorAction SilentlyContinue  

If($zonetest -ne $null)
{
  Write-Host "Forward Lookup Zone ($forwardZone) Already Exists"
}
else
{
   $newZone = Add-DnsServerPrimaryZone -Name $forwardZone -ReplicationScope "Domain" -PassThru

   if($newZone.ZoneName -eq "$forwardZone")
   {
      Write-Host "Created Forward Lookup Zone ($forwardZone)"
   }
   else
   {
      Write-Host "Error Creating New Zone ($forwardZone)"
   }
}
Write-Host "===== COMPLETED FORWARD LOOKUP ZONE CREATION ====="
##########################################################################
# Create DNS Reverse Zone
##########################################################################
Write-Host "===== START REVERSE LOOKUP ZONE CREATION ====="
$ifidx  = (get-NetAdapter).interfaceindex
$mask   = (get-NetIPAddress -InterfaceIndex $ifidx -AddressFamily IPv4).PrefixLength
$ipv4   = (get-NetIPAddress -InterfaceIndex $ifidx -AddressFamily IPv4).IPAddress
$ipaddr = $ipv4.Split(".")

$ipMask = $ipaddr[0] + "." + $ipaddr[1] + "." + $ipaddr[2] + ".0/" + "$mask"
$reverse = $ipaddr[2] + "." + $ipaddr[1] + "." + $ipaddr[0] + ".in-addr.arpa"

Write-Host "Reverse IP Address: $reverse"

$zonetest = get-DnsServerZone -Name $reverse -ErrorAction SilentlyContinue

If($zonetest -ne $null)
{
  Write-Host "Reverse Lookup Zone ($reverse) Already Exists"
}
else
{
   $NewZone = Add-DnsServerPrimaryZone -NetworkID $ipMask -ReplicationScope Domain -PassThru
   
   if($newZone.ZoneName -eq "$reverse")
   {
      Write-Host "Created Reverse Lookup Zone ($reverse)"
   }
   else
   {
      Write-Host "Error Creating New Zone ($reverse)"
   }   
}
Write-Host "===== COMPLETED REVERSE LOOKUP ZONE CREATION ====="
##########################################################################
# Create .(root) Zone - to block roothints
##########################################################################
Write-Host "===== START ROOT LOOKUP ZONE CREATION ====="

$rootZone = "."

"ROOT Zone: $rootZone"

$zonetest = get-DnsServerZone -Name $rootZone -ErrorAction SilentlyContinue

If($zonetest -ne $null)
{
   Write-Host "Forward Lookup Zone ($rootZone) Already Exists" | Write-log
}
else
{
   $newZone = Add-DnsServerPrimaryZone -Name $rootZone -ReplicationScope "Domain" -PassThru

   if($newZone.ZoneName -eq "$rootZone")
   {
    Write-Host "Created Forward Lookup Zone ($rootZone)"
   }
   else
   {
    Write-Host "Error Creating New Zone ($rootZone)"
   }
}
##########################################################################
# Turn on Scavenging
##########################################################################
Write-Host "Enable Scavenging on all zones"

$scavengeCheck = Set-DnsServerScavenging -ApplyOnAllZones -RefreshInterval 1.00:00:00 -ScavengingState:$true -PassThru -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

Write-Output $scavengeCheck
##########################################################################
# Increase Tombstone Lifetime to 1 Year (365 Days)
##########################################################################
Write-Host " Set Tombstone Lifetime to 365 Days "

import-module ActiveDirectory

$ADDomainName = Get-ADDomain

$ADname = $ADDomainName.DistinguishedName

Set-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$ADname" -Partition "CN=Configuration,$ADname" -Replace @{tombstoneLifetime='365'}

Write-Host "Tombstone Lifetime set to 365 days"
##########################################################################
# Delete DNS Cache
##########################################################################
if(test-path "c:\windows\system32\dns\CACHE.DNS")
{
   Remove-Item "c:\windows\system32\dns\CACHE.DNS"
   "DNS Cache Deleted" | out-null
}
Write-Host "===== COMPLETED ROOT LOOKUP ZONE CREATION ====="
##########################################################################
# Update DNS Entries for Active NIC
##########################################################################
if(test-path "c:\scripts\firstDC.txt")
{
   $dnsResult = Set-DnsClientServerAddress -InterfaceIndex $ifidx -ServerAddresses ("$ipv4", "127.0.0.1") -Confirm:$false
}

##########################################################################
. .\"modSchema-2012.ps1"

. .\"createAccounts-2012.ps1"

. .\"createDCGSaccounts-2012.ps1"

. .\"createCMDWEB-2012.ps1"

. .\"createC2Iaccounts-2012.ps1"

. .\"createGCCS4.3accounts-2012.ps1"

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
        Write-Host "Copied Active Directory Users and Computers to Desktop"
    }
}
 else
{
    Write-host " Could not find Active Directory Users and Computers Shortcut (?!?!?!)`n" 
    write-host "`n`n Make sure AD Post Installation is complete!!!`n" 
    Set-Location "C:\Scripts"
    Write-Host "WARNING: Could not find Active Directory Users and Computers Shortcut"
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
        Write-Host "Copied DNS shortcut to Desktop"
    }
}
 else
{
    Write-host " Could not find DNS Edit Shortcut (?!?!?!)`n" 
    write-host "`n`n Make sure AD Post Installation is complete!!!`n" 
    Set-Location "C:\Scripts"
    Write-Host "WARNING: Could not find DNS Shortcut"
    Exit
}
Write-Host "===== COMPLETED INSTALLATION - ADpostinstall-2012.ps1 ====="
##########################################################################
